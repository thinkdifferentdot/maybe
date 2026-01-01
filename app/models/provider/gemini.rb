class Provider::Gemini < Provider
  include LlmConcept

  Error = Class.new(Provider::Error)

  MODELS = %w[gemini-1.5-flash gemini-1.5-pro]

  FALLBACK_MODELS = [
    ["Gemini 2.0 Flash (Recommended)", "gemini-2.0-flash-exp"],
    ["Gemini 1.5 Flash", "gemini-1.5-flash"],
    ["Gemini 1.5 Pro", "gemini-1.5-pro"]
  ].freeze

  def self.list_available_models
    Rails.cache.fetch("gemini_available_models", expires_in: 24.hours) do
      # Placeholder for actual API call
      FALLBACK_MODELS
    end
  rescue => e
    Rails.logger.error("Failed to fetch Gemini models: #{e.message}")
    FALLBACK_MODELS
  end

  def initialize(api_key)
    @client = ::Gemini.new(
      credentials: {
        service: "generative-language-api",
        api_key: api_key
      },
      options: { model: Setting.gemini_categorization_model, server_sent_events: true }
    )
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

  # TODO: Implement auto_detect_merchants and chat_response later if needed
  def auto_detect_merchants(transactions: [], user_merchants: [])
    raise NotImplementedError
  end

  def chat_response(prompt, model:, instructions: nil, functions: [], function_results: [], streamer: nil, previous_response_id: nil)
    raise NotImplementedError
  end

  private
    attr_reader :client
end
