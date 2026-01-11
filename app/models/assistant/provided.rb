module Assistant::Provided
  extend ActiveSupport::Concern

  def get_model_provider(ai_model)
    # Order providers by user's preference (llm_provider setting)
    ordered_providers = ordered_providers_by_preference
    ordered_providers.find { |provider| provider&.supports_model?(ai_model) }
  end

  private
    def registry
      @registry ||= Provider::Registry.for_concept(:llm)
    end

    def ordered_providers_by_preference
      preferred_provider = Setting.llm_provider.presence&.to_sym

      # Get all available providers as instances
      all_providers = registry.providers

      # If no preference set, return all providers in default order
      return all_providers unless preferred_provider

      # Try to get the preferred provider instance
      preferred_instance = registry.get_provider(preferred_provider) rescue nil

      # If preferred provider is not configured, return all providers in default order
      return all_providers unless preferred_instance

      # Put preferred provider first, then others in default order
      [ preferred_instance ] + all_providers.reject { |p| p.is_a?(preferred_instance.class) }
    end
end
