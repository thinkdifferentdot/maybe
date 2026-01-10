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

  private
    attr_reader :client
end
