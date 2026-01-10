class Provider::Anthropic < Provider
  include LlmConcept

  # Subclass so errors caught in this provider are raised as Provider::Anthropic::Error
  Error = Class.new(Provider::Error)

  # Supported Anthropic model prefixes (e.g., "claude-sonnet", "claude-opus", etc.)
  DEFAULT_ANTHROPIC_MODEL_PREFIXES = %w[claude-]
  DEFAULT_MODEL = "claude-sonnet-4-5-20250929"

  def initialize(access_token, model: nil)
    raise NotImplementedError, "Client initialization to be implemented in plan 1-03"
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
end
