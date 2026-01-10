class Provider::Anthropic < Provider
  include LlmConcept

  # Subclass so errors caught in this provider are raised as Provider::Anthropic::Error
  Error = Class.new(Provider::Error)

  # Supported Anthropic model prefixes (e.g., "claude-sonnet", "claude-opus", etc.)
  DEFAULT_ANTHROPIC_MODEL_PREFIXES = %w[claude-]
  DEFAULT_MODEL = "claude-sonnet-4-5-20250929"

  class << self
    # Returns the effective model that would be used by the provider
    # Uses the same logic as Provider::Registry and the initializer
    def effective_model
      configured_model = ENV.fetch("ANTHROPIC_MODEL", nil)
      configured_model.presence || DEFAULT_MODEL
    end
  end

  def initialize(access_token, model: nil)
    @client = ::Anthropic::Client.new(api_key: access_token)
    @default_model = model.presence || DEFAULT_MODEL
  end

  def provider_name
    "Anthropic"
  end

  def supports_model?(model)
    DEFAULT_ANTHROPIC_MODEL_PREFIXES.any? { |prefix| model.start_with?(prefix) }
  end

  def supported_models_description
    "models starting with: #{DEFAULT_ANTHROPIC_MODEL_PREFIXES.join(', ')}"
  end

  def auto_categorize(transactions: [], user_categories: [], model: "", family: nil)
    with_provider_response do
      raise Error, "Too many transactions to auto-categorize. Max is 25 per request." if transactions.size > 25
      if user_categories.blank?
        family_id = family&.id || "unknown"
        Rails.logger.error("Cannot auto-categorize transactions for family #{family_id}: no categories available")
        raise Error, "No categories available for auto-categorization"
      end

      effective_model = model.presence || @default_model

      trace = create_langfuse_trace(
        name: "anthropic.auto_categorize",
        input: { transactions: transactions, user_categories: user_categories }
      )

      result = AutoCategorizer.new(
        client,
        model: effective_model,
        transactions: transactions,
        user_categories: user_categories,
        langfuse_trace: trace,
        family: family
      ).auto_categorize

      trace&.update(output: result.map(&:to_h))

      result
    end
  end

  private

    attr_reader :client

    def langfuse_client
      return unless ENV["LANGFUSE_PUBLIC_KEY"].present? && ENV["LANGFUSE_SECRET_KEY"].present?

      @langfuse_client = Langfuse.new
    end

    def create_langfuse_trace(name:, input:, session_id: nil, user_identifier: nil)
      return unless langfuse_client

      langfuse_client.trace(
        name: name,
        input: input,
        session_id: session_id,
        user_id: user_identifier,
        environment: Rails.env
      )
    rescue => e
      Rails.logger.warn("Langfuse trace creation failed: #{e.message}")
      nil
    end
end
