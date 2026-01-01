class Provider::Anthropic < Provider
  include LlmConcept

  Error = Class.new(Provider::Error)

  MODELS = %w[claude-3-5-sonnet-20241022 claude-3-5-haiku-20241022]

  def initialize(api_key)
    @client = ::Anthropic::Client.new(api_key: api_key)
  end

  def supports_model?(model)
    MODELS.include?(model)
  end

  def auto_categorize(transactions: [], user_categories: [])
    with_provider_response do
      raise Error, "Too many transactions to auto-categorize. Max is 25 per request." if transactions.size > 25

      AutoCategorizer.new(
        client,
        transactions: transactions,
        user_categories: user_categories
      ).auto_categorize
    end
  end

  def auto_detect_merchants(transactions: [], user_merchants: [])
    raise NotImplementedError
  end

  def chat_response(prompt, model:, instructions: nil, functions: [], function_results: [], streamer: nil, previous_response_id: nil)
    raise NotImplementedError
  end

  private
    attr_reader :client
end
