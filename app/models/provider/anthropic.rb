class Provider::Anthropic < Provider
  include LlmConcept

  Error = Class.new(Provider::Error)

  MODELS = %w[claude-3-5-sonnet-20241022 claude-3-5-haiku-20241022]

  FALLBACK_MODELS = [
    ["Claude 3.5 Sonnet (Recommended)", "claude-3-5-sonnet-20241022"],
    ["Claude 3.5 Haiku", "claude-3-5-haiku-20241022"],
    ["Claude 3 Opus", "claude-3-opus-20240229"]
  ].freeze

  def self.list_available_models
    Rails.cache.fetch("anthropic_available_models", expires_in: 24.hours) do
      # Anthropic API doesn't expose a simple models list endpoint in the same way,
      # or requires different handling. Using curated list for now.
      FALLBACK_MODELS
    end
  rescue => e
    Rails.logger.error("Failed to fetch Anthropic models: #{e.message}")
    FALLBACK_MODELS
  end

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
