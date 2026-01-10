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

    response = client.messages.create(
      model: model,
      max_tokens: 1024,
      messages: [{role: "user", content: developer_message}],
      system: instructions,
      betas: ["structured-outputs-2025-11-13"]
    )

    Rails.logger.info("Tokens used to auto-categorize transactions: #{response.usage.total_tokens}")

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
      total_tokens: response.usage.total_tokens
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
    MESSAGE
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
                enum: [*user_categories.map { |c| c[:name] }, "null"]
              }
            },
            required: ["transaction_id", "category_name"],
            additionalProperties: false
          }
        }
      },
      required: ["categorizations"],
      additionalProperties: false
    }
  end

  def extract_categorizations(response)
    content_block = response.content.find { |block| block.type == "text" }
    raise Provider::Anthropic::Error, "No text content found in response" if content_block.nil?

    parsed = JSON.parse(content_block.text)
    parsed.dig("categorizations") || []
  rescue JSON::ParserError => e
    raise Provider::Anthropic::Error, "Invalid JSON in categorization response: #{e.message}"
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

    normalized
  end

  def record_usage(model_name, usage_data, operation:, metadata: {})
    return unless family && usage_data

    LlmUsage.calculate_cost(
      model: model_name,
      prompt_tokens: usage_data.input_tokens,
      completion_tokens: usage_data.output_tokens
    ).yield_self do |estimated_cost|
      if estimated_cost.nil?
        Rails.logger.info("Recording LLM usage without cost estimate for unknown model: #{model_name}")
      end

      family.llm_usages.create!(
        provider: LlmUsage.infer_provider(model_name),
        model: model_name,
        operation: operation,
        prompt_tokens: usage_data.input_tokens,
        completion_tokens: usage_data.output_tokens,
        total_tokens: usage_data.total_tokens,
        estimated_cost: estimated_cost,
        metadata: metadata
      )

      Rails.logger.info("LLM usage recorded - Operation: #{operation}, Cost: #{estimated_cost.inspect}")
    end
  rescue => e
    Rails.logger.error("Failed to record LLM usage: #{e.message}")
  end
end
