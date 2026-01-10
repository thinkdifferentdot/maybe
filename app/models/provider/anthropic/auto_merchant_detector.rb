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
      messages: [{role: "user", content: developer_message}],
      system: instructions,
      betas: ["structured-outputs-2025-11-13"]
    )

    Rails.logger.info("Tokens used to auto-detect merchants: #{response.usage.total_tokens}")

    merchants = extract_merchants(response)
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
      total_tokens: response.usage.total_tokens
    })

    result
  rescue => e
    span&.end(output: { error: e.message }, level: "ERROR")
    raise
  end

  private

  AutoDetectedMerchant = Provider::LlmConcept::AutoDetectedMerchant

  def developer_message
    # Will be implemented in Task 3
    ""
  end

  def instructions
    # Will be implemented in Task 3
    ""
  end

  def json_schema
    # Will be implemented in Task 3
    {}
  end

  def build_response(merchants)
    merchants.map do |merchant|
      AutoDetectedMerchant.new(
        transaction_id: merchant.dig("transaction_id"),
        business_name: normalize_merchant_value(merchant.dig("business_name")),
        business_url: normalize_merchant_value(merchant.dig("business_url"))
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

  def extract_merchants(response)
    content_block = response.content.find { |block| block.type == "text" }
    raise Provider::Anthropic::Error, "No text content found in response" if content_block.nil?

    parsed = JSON.parse(content_block.text)
    parsed.dig("merchants") || []
  rescue JSON::ParserError => e
    raise Provider::Anthropic::Error, "Invalid JSON in merchant detection response: #{e.message}"
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
