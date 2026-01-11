class Provider::Anthropic::AutoMerchantDetector
  attr_reader :client, :model, :transactions, :user_merchants, :langfuse_trace, :family

  def initialize(client, model:, transactions:, user_merchants:, langfuse_trace: nil, family: nil)
    @client = client
    @model = model
    @transactions = transactions
    @user_merchants = user_merchants
    @langfuse_trace = langfuse_trace
    @family = family
  end

  def auto_detect_merchants
    span = langfuse_trace&.span(name: "auto_detect_merchants_api_call", input: {
      model: model,
      transactions: transactions,
      user_merchants: user_merchants
    })

    response = client.messages.create(
      model: model,
      max_tokens: 1024,
      messages: [ { role: "user", content: developer_message } ],
      system: instructions
    )

    # Note: response.usage is an Anthropic::Models::Usage BaseModel with input_tokens/output_tokens attributes
    usage_total = response.usage.input_tokens + response.usage.output_tokens
    Rails.logger.info("Tokens used to auto-detect merchants: #{usage_total}")

    merchants = extract_merchants(response)
    Rails.logger.debug("Extracted merchants: #{merchants.inspect}")
    result = build_response(merchants)

    record_usage(
      model,
      response.usage,
      operation: "auto_detect_merchants",
      metadata: {
        transaction_count: transactions.size,
        merchant_count: user_merchants.size
      }
    )

    span&.end(output: result.map(&:to_h), usage: {
      input_tokens: response.usage.input_tokens,
      output_tokens: response.usage.output_tokens,
      total_tokens: usage_total
    })

    result
  rescue Anthropic::Errors::APIConnectionError => e
    span&.end(output: { error: e.message }, level: "ERROR")
    raise Provider::Anthropic::Error, "Failed to connect to Anthropic API: #{e.message}"
  rescue Anthropic::Errors::APITimeoutError => e
    span&.end(output: { error: e.message }, level: "ERROR")
    raise Provider::Anthropic::Error, "Anthropic API request timed out: #{e.message}"
  rescue Anthropic::Errors::RateLimitError => e
    span&.end(output: { error: e.message }, level: "ERROR")
    raise Provider::Anthropic::Error, "Anthropic API rate limit exceeded: #{e.message}"
  rescue Anthropic::Errors::AuthenticationError => e
    span&.end(output: { error: e.message }, level: "ERROR")
    raise Provider::Anthropic::Error, "Anthropic API authentication failed: #{e.message}"
  rescue Anthropic::Errors::APIStatusError => e
    span&.end(output: { error: e.message, status: e.status }, level: "ERROR")
    raise Provider::Anthropic::Error, "Anthropic API error (#{e.status}): #{e.message}"
  rescue JSON::ParserError => e
    span&.end(output: { error: e.message }, level: "ERROR")
    raise Provider::Anthropic::Error, "Invalid JSON response from Anthropic: #{e.message}"
  rescue => e
    span&.end(output: { error: e.message }, level: "ERROR")
    raise Provider::Anthropic::Error, "Unexpected error during merchant detection: #{e.message}"
  end

  private

    AutoDetectedMerchant = Provider::LlmConcept::AutoDetectedMerchant

    def developer_message
      <<~MESSAGE.strip_heredoc
      Here are the user's available merchants in JSON format:

      ```json
      #{user_merchants.to_json}
      ```

      Use BOTH your knowledge AND the user-generated merchants to auto-detect the following transactions:

      ```json
      #{transactions.to_json}
      ```

      Return "null" if you are not 80%+ confident in your answer.
    MESSAGE
    end

    def instructions
      <<~INSTRUCTIONS.strip_heredoc
      You are an assistant to a consumer personal finance app.

      Closely follow ALL the rules below while auto-detecting business names and website URLs:

      - Return 1 result per transaction
      - Correlate each transaction by ID (transaction_id)
      - Do not include the subdomain in the business_url (i.e. "amazon.com" not "www.amazon.com")
      - User merchants are considered "manual" user-generated merchants and should only be used in 100% clear cases
      - Be slightly pessimistic.  We favor returning "null" over returning a false positive.
      - NEVER return a name or URL for generic transaction names (e.g. "Paycheck", "Laundromat", "Grocery store", "Local diner")

      Determining a value:

      - First attempt to determine the name + URL from your knowledge of global businesses
      - If no certain match, attempt to match one of the user-provided merchants
      - If no match, return "null"

      Example 1 (known business):

      ```
      Transaction name: "Some Amazon purchases"

      Result:
      - business_name: "Amazon"
      - business_url: "amazon.com"
      ```

      Example 2 (generic business):

      ```
      Transaction name: "local diner"

      Result:
      - business_name: null
      - business_url: null
      ```
    INSTRUCTIONS
    end

    def json_schema
      {
        type: "object",
        properties: {
          merchants: {
            type: "array",
            description: "An array of auto-detected merchant businesses for each transaction",
            items: {
              type: "object",
              properties: {
                transaction_id: {
                  type: "string",
                  description: "The internal ID of the original transaction",
                  enum: transactions.map { |t| t[:id] }
                },
                business_name: {
                  type: [ "string", "null" ],
                  description: "The detected business name of the transaction, or `null` if uncertain"
                },
                business_url: {
                  type: [ "string", "null" ],
                  description: "The URL of the detected business, or `null` if uncertain"
                }
              },
              required: [ "transaction_id", "business_name", "business_url" ],
              additionalProperties: false
            }
          }
        },
        required: [ "merchants" ],
        additionalProperties: false
      }
    end

    def build_response(merchants)
      merchants.map do |merchant|
        # Handle both string and symbol keys
        transaction_id = merchant["transaction_id"] || merchant[:transaction_id]
        business_name = merchant["business_name"] || merchant[:business_name]
        business_url = merchant["business_url"] || merchant[:business_url]

        AutoDetectedMerchant.new(
          transaction_id: transaction_id,
          business_name: normalize_merchant_value(business_name),
          business_url: normalize_merchant_value(business_url)
        )
      end
    end

    def normalize_merchant_value(value)
      return nil if value.nil? || value == "null" || value.to_s.downcase == "null"

      # Try to match against user merchants for name normalization
      if user_merchants.present?
        # Try exact match first
        exact_match = user_merchants.find { |m| m[:name] == value }
        return exact_match[:name] if exact_match

        # Try case-insensitive match
        case_match = user_merchants.find { |m| m[:name].to_s.downcase == value.to_s.downcase }
        return case_match[:name] if case_match
      end

      value
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
      # Handle both objects {...} and arrays [...]
      if cleaned =~ /```(?:json)?\s*(\[[\s\S]*?\])\s*```/m
        matches = cleaned.scan(/```(?:json)?\s*(\[[\s\S]*?\])\s*```/m).flatten
        matches.reverse_each do |match|
          begin
            return JSON.parse(match)
          rescue JSON::ParserError
            next
          end
        end
      end

      # Strategy 1b: Closed markdown code blocks with objects (fallback)
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
      # Pattern: ```json followed by JSON (array or object) that goes to end of string
      if cleaned =~ /```(?:json)?\s*(\[[\s\S]*\])\s*$/m
        begin
          return JSON.parse($1)
        rescue JSON::ParserError
          # Continue to next strategy
        end
      end

      # Strategy 2b: Unclosed markdown code blocks with objects
      if cleaned =~ /```(?:json)?\s*(\{[\s\S]*\})\s*$/m
        begin
          return JSON.parse($1)
        rescue JSON::ParserError
          # Continue to next strategy
        end
      end

      # Strategy 3: Find JSON object with "merchants" key
      if cleaned =~ /(\{"merchants"\s*:\s*\[[\s\S]*\]\s*\})/m
        matches = cleaned.scan(/(\{"merchants"\s*:\s*\[[\s\S]*?\]\s*\})/m).flatten
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

    def extract_merchants(response)
      # Note: response.content contains BaseModel objects with symbolized type attributes
      content_block = response.content.find { |block| block.type == :text }
      raise Provider::Anthropic::Error, "No text content found in response" if content_block.nil?

      # Use flexible JSON parsing to handle various LLM output formats
      parsed = parse_json_flexibly(content_block.text)

      # Handle both { "merchants": [...] } and direct [...] formats
      if parsed.is_a?(Array)
        merchants = parsed
      else
        merchants = parsed.dig("merchants") || []
      end
      merchants
    rescue JSON::ParserError => e
      raise Provider::Anthropic::Error, "Invalid JSON in merchant detection response: #{e.message}"
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
