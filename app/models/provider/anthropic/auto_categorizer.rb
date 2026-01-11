class Provider::Anthropic::AutoCategorizer
  attr_reader :client, :model, :transactions, :user_categories, :langfuse_trace, :family

  def initialize(client, model:, transactions: [], user_categories: [], langfuse_trace: nil, family: nil)
    @client = client
    @model = model
    @transactions = transactions
    @user_categories = user_categories
    @langfuse_trace = langfuse_trace
    @family = family
  end

  def auto_categorize
    span = langfuse_trace&.span(name: "auto_categorize_api_call", input: {
      model: model,
      transactions: transactions,
      user_categories: user_categories
    })

    # Use tool use for structured JSON output
    response = client.messages.create(
      model: model,
      max_tokens: 4096,
      messages: [ { role: "user", content: developer_message } ],
      system: instructions,
      tools: [ categorization_tool ]
    )

    # Note: response.usage is an Anthropic::Models::Usage BaseModel with input_tokens/output_tokens attributes
    usage_total = response.usage.input_tokens + response.usage.output_tokens
    Rails.logger.info("Tokens used to auto-categorize transactions: #{usage_total}")

    categorizations = extract_categorizations(response)
    result = build_response(categorizations)

    record_usage(
      model,
      response.usage,
      operation: "auto_categorize",
      metadata: {
        transaction_count: transactions.size,
        category_count: user_categories.size
      }
    )

    span&.end(output: result.map(&:to_h), usage: {
      input_tokens: response.usage.input_tokens,
      output_tokens: response.usage.output_tokens,
      total_tokens: usage_total
    })

    result
  rescue => e
    span&.end(output: { error: e.message }, level: "ERROR")
    raise
  end

  private

    AutoCategorization = Provider::LlmConcept::AutoCategorization

    def instructions
      <<~INSTRUCTIONS.strip_heredoc
      You are an assistant to a consumer personal finance app.  You will be provided a list
      of the user's transactions and a list of the user's categories.  Your job is to auto-categorize
      each transaction.

      Closely follow ALL the rules below while auto-categorizing:

      - Return 1 result per transaction
      - Correlate each transaction by ID (transaction_id)
      - Attempt to match the most specific category possible (i.e. subcategory over parent category)
      - Category and transaction classifications should match (i.e. if transaction is an "expense", the category must have classification of "expense")
      - If you don't know the category, return "null"
        - You should always favor "null" over false positives
        - Be slightly pessimistic.  Only match a category if you're 60%+ confident it is the correct one.
      - Each transaction has varying metadata that can be used to determine the category
        - Note: "hint" comes from 3rd party aggregators and typically represents a category name that
          may or may not match any of the user-supplied categories
    INSTRUCTIONS
    end

    def developer_message
      <<~MESSAGE.strip_heredoc
      Here are the user's available categories in JSON format:

      ```json
      #{user_categories.to_json}
      ```

      Use the available categories to auto-categorize the following transactions:

      ```json
      #{transactions.to_json}
      ```

      Use the categorize_transactions tool to provide your categorizations.
    MESSAGE
    end

    # Tool definition for structured output
    def categorization_tool
      {
        name: "categorize_transactions",
        description: "Categorize the provided transactions into the user's categories",
        input_schema: {
          type: "object",
          properties: {
            categorizations: {
              type: "array",
              description: "An array of auto-categorizations for each transaction",
              items: {
                type: "object",
                properties: {
                  transaction_id: {
                    type: "string",
                    description: "The internal ID of the original transaction",
                    enum: transactions.map { |t| t[:id] }
                  },
                  category_name: {
                    type: "string",
                    description: "The matched category name of the transaction, or null if no match",
                    enum: [ *user_categories.map { |c| c[:name] }, "null" ]
                  }
                },
                required: [ "transaction_id", "category_name" ],
                additionalProperties: false
              }
            }
          },
          required: [ "categorizations" ],
          additionalProperties: false
        }
      }
    end

    def json_schema
      {
        type: "object",
        properties: {
          categorizations: {
            type: "array",
            description: "An array of auto-categorizations for each transaction",
            items: {
              type: "object",
              properties: {
                transaction_id: {
                  type: "string",
                  description: "The internal ID of the original transaction",
                  enum: transactions.map { |t| t[:id] }
                },
                category_name: {
                  type: "string",
                  description: "The matched category name of the transaction, or null if no match",
                  enum: [ *user_categories.map { |c| c[:name] }, "null" ]
                }
              },
              required: [ "transaction_id", "category_name" ],
              additionalProperties: false
            }
          }
        },
        required: [ "categorizations" ],
        additionalProperties: false
      }
    end

    def extract_categorizations(response)
      # Note: response.content contains BaseModel objects with symbolized type attributes
      # When using tools, the model returns a tool_use block with the structured data
      tool_block = response.content.find { |block| block.type == :tool_use }

      if tool_block.nil?
        # Fallback: try to find text content for backward compatibility
        text_block = response.content.find { |block| block.type == :text }
        if text_block.nil?
          # Log all content blocks for debugging
          Rails.logger.error("No tool_use or text content found. Response content types: #{response.content.map(&:type).inspect}")
          raise Provider::Anthropic::Error, "No tool_use or text content found in response"
        end

        # Use flexible JSON parsing to handle various LLM output formats
        parsed = parse_json_flexibly(text_block.text)

        # Handle both { "categorizations": [...] } and direct [...] formats
        if parsed.is_a?(Array)
          return parsed
        else
          return parsed.dig("categorizations") || []
        end
      end

      # Extract the tool input (structured data)
      # Convert the BaseModel to hash to access the input field
      # Note: to_h returns a hash with symbol keys, not string keys
      tool_hash = tool_block.to_h
      tool_input = tool_hash.dig(:input)
      # Use symbol key since the hash has symbolized keys
      categorizations = tool_input&.dig(:categorizations) || []

      # Convert symbol keys to string keys for consistency with the rest of the codebase
      categorizations.map do |c|
        # Convert hash with symbol keys to hash with string keys
        c.transform_keys(&:to_s)
      end
    rescue JSON::ParserError => e
      raise Provider::Anthropic::Error, "Invalid JSON in categorization response: #{e.message}"
    rescue => e
      raise Provider::Anthropic::Error, "Failed to extract categorizations: #{e.message}"
    end

    def build_response(categorizations)
      categorizations.map do |categorization|
        AutoCategorization.new(
          transaction_id: categorization.dig("transaction_id"),
          category_name: normalize_category_name(categorization.dig("category_name")),
        )
      end
    end

    def normalize_category_name(category_name)
      return nil if category_name.nil? || category_name == "null"

      normalized = category_name.to_s.strip
      return nil if normalized.empty? || normalized == "null"

      # Try exact match first
      exact_match = user_categories.find { |c| c[:name] == normalized }
      return exact_match[:name] if exact_match

      # Try case-insensitive match
      case_insensitive_match = user_categories.find { |c| c[:name].to_s.downcase == normalized.downcase }
      return case_insensitive_match[:name] if case_insensitive_match

      # Try partial/fuzzy match (for common variations)
      fuzzy_match = find_fuzzy_category_match(normalized)
      return fuzzy_match if fuzzy_match

      normalized
    end

    # Find a fuzzy match for category names with common variations
    def find_fuzzy_category_match(category_name)
      # Ensure string input for string operations
      input_str = category_name.to_s
      normalized_input = input_str.downcase.gsub(/[^a-z0-9]/, "")

      user_categories.each do |cat|
        cat_name_str = cat[:name].to_s
        normalized_cat = cat_name_str.downcase.gsub(/[^a-z0-9]/, "")

        # Check if one contains the other
        return cat[:name] if normalized_input.include?(normalized_cat) || normalized_cat.include?(normalized_input)

        # Check common abbreviations/variations
        return cat[:name] if fuzzy_name_match?(input_str, cat_name_str)
      end

      nil
    end

    # Handle common naming variations
    def fuzzy_name_match?(input, category)
      variations = {
        "gas" => [ "gas & fuel", "gas and fuel", "fuel", "gasoline" ],
        "restaurants" => [ "restaurant", "dining", "food" ],
        "groceries" => [ "grocery", "supermarket", "food store" ],
        "streaming" => [ "streaming services", "streaming service" ],
        "rideshare" => [ "ride share", "ride-share", "uber", "lyft" ],
        "coffee" => [ "coffee shops", "coffee shop", "cafe" ],
        "fast food" => [ "fastfood", "quick service" ],
        "gym" => [ "gym & fitness", "fitness", "gym and fitness" ],
        "flights" => [ "flight", "airline", "airlines", "airfare" ],
        "hotels" => [ "hotel", "lodging", "accommodation" ]
      }

      # Ensure string inputs for string operations
      input_lower = input.to_s.downcase
      category_lower = category.to_s.downcase

      variations.each do |_key, synonyms|
        if synonyms.include?(input_lower) && synonyms.include?(category_lower)
          return true
        end
      end

      false
    end

    # Flexible JSON parsing that handles common LLM output issues
    def parse_json_flexibly(raw)
      return {} if raw.blank?

      # Strip thinking model tags if present (e.g., <thinking>...</thinking>)
      # The actual JSON output comes after the thinking block
      cleaned = strip_thinking_tags(raw)

      # Try direct parse first
      JSON.parse(cleaned)
    rescue JSON::ParserError
      # Try multiple extraction strategies in order of preference

      # Strategy 1: Closed markdown code blocks (```json...```)
      if cleaned =~ /```(?:json)?\s*(\{[\s\S]*?\})\s*```/m
        matches = cleaned.scan(/```(?:json)?\s*(\{[\s\S]*?\})\s*```/m).flatten
        matches.reverse_each do |match|
          begin
            return JSON.parse(match)
          rescue JSON::ParserError
            next
          end
        end
      end

      # Strategy 2: Unclosed markdown code blocks (thinking models often forget to close)
      # Pattern: ```json followed by JSON that goes to end of string
      if cleaned =~ /```(?:json)?\s*(\{[\s\S]*\})\s*$/m
        begin
          return JSON.parse($1)
        rescue JSON::ParserError
          # Continue to next strategy
        end
      end

      # Strategy 3: Find JSON object with "categorizations" key
      if cleaned =~ /(\{"categorizations"\s*:\s*\[[\s\S]*\]\s*\})/m
        matches = cleaned.scan(/(\{"categorizations"\s*:\s*\[[\s\S]*?\]\s*\})/m).flatten
        matches.reverse_each do |match|
          begin
            return JSON.parse(match)
          rescue JSON::ParserError
            next
          end
        end
        # Try greedy match if non-greedy failed
        begin
          return JSON.parse($1)
        rescue JSON::ParserError
          # Continue to next strategy
        end
      end

      # Strategy 4: Find any JSON object (last resort)
      if cleaned =~ /(\{[\s\S]*\})/m
        begin
          return JSON.parse($1)
        rescue JSON::ParserError
          # Fall through to error
        end
      end

      raise Provider::Anthropic::Error, "Could not parse JSON from response: #{raw.truncate(200)}"
    end

    # Strip thinking model tags (<thinking>...</thinking>) from response
    # Some models like Qwen-thinking output reasoning in these tags before the actual response
    def strip_thinking_tags(raw)
      # Remove <thinking> blocks but keep content after them
      # If no closing tag, the model may have been cut off - try to extract JSON from inside
      if raw.include?("<thinking>")
        # Check if there's content after the thinking block
        if raw =~ /<\/think>\s*([\s\S]*)/m
          after_thinking = $1.strip
          return after_thinking if after_thinking.present?
        end
        # If no content after </thinking> or no closing tag, look inside the thinking block
        # The JSON might be the last thing in the thinking block
        if raw =~ /<thinking>([\s\S]*)/m
          return $1
        end
      end
      raw
    end

    def record_usage(model_name, usage_data, operation:, metadata: {})
      return unless family && usage_data

      # Note: usage_data is an Anthropic::Models::Usage BaseModel with input_tokens/output_tokens attributes
      input_toks = usage_data.input_tokens
      output_toks = usage_data.output_tokens
      total_toks = input_toks + output_toks

      LlmUsage.calculate_cost(
        model: model_name,
        prompt_tokens: input_toks,
        completion_tokens: output_toks
      ).yield_self do |estimated_cost|
        if estimated_cost.nil?
          Rails.logger.info("Recording LLM usage without cost estimate for unknown model: #{model_name}")
        end

        family.llm_usages.create!(
          provider: LlmUsage.infer_provider(model_name),
          model: model_name,
          operation: operation,
          prompt_tokens: input_toks,
          completion_tokens: output_toks,
          total_tokens: total_toks,
          estimated_cost: estimated_cost,
          metadata: metadata
        )

        Rails.logger.info("LLM usage recorded - Operation: #{operation}, Cost: #{estimated_cost.inspect}")
      end
    rescue => e
      Rails.logger.error("Failed to record LLM usage: #{e.message}")
    end
end
