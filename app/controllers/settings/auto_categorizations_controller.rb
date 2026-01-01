class Settings::AutoCategorizationsController < ApplicationController
  layout "settings"

  def edit
    @available_models = fetch_available_models
  end

  def update
    settings = auto_categorization_params
    errors = validate_settings(settings)

    if errors.any?
      flash.now[:alert] = errors.join(", ")
      @available_models = fetch_available_models
      render :edit, status: :unprocessable_entity
    else
      settings.each do |key, value|
        Setting.send("#{key}=", value)
      end
      redirect_to edit_settings_auto_categorization_path, notice: t(".updated")
    end
  end

  private

  def validate_settings(settings)
    errors = []

    if settings.key?(:categorization_confidence_threshold)
      val = settings[:categorization_confidence_threshold].to_i
      errors << "Confidence threshold must be between 0 and 100" unless val.between?(0, 100)
    end

    if settings.key?(:categorization_batch_size)
      val = settings[:categorization_batch_size].to_i
      errors << "Batch size must be between 10 and 200" unless val.between?(10, 200)
    end

    if settings.key?(:categorization_null_tolerance)
      errors << "Invalid null tolerance" unless %w[pessimistic balanced optimistic].include?(settings[:categorization_null_tolerance])
    end

    errors
  end

  def auto_categorization_params
    params.require(:setting).permit(
      :openai_categorization_model,
      :anthropic_categorization_model,
      :gemini_categorization_model,
      :categorization_confidence_threshold,
      :categorization_batch_size,
      :categorization_prefer_subcategories,
      :categorization_enforce_classification_match,
      :categorization_null_tolerance
    )
  end

  def fetch_available_models
    {
      openai: fetch_openai_models,
      anthropic: fetch_anthropic_models,
      gemini: fetch_gemini_models
    }
  end

  def fetch_openai_models
    return nil unless Setting.openai_access_token.present?
    Provider::Openai.list_available_models
  rescue => e
    Rails.logger.error("Failed to fetch OpenAI models: #{e.message}")
    Provider::Openai::FALLBACK_MODELS
  end

  def fetch_anthropic_models
    return nil unless Setting.anthropic_api_key.present?
    Provider::Anthropic.list_available_models
  rescue => e
    Rails.logger.error("Failed to fetch Anthropic models: #{e.message}")
    Provider::Anthropic::FALLBACK_MODELS
  end

  def fetch_gemini_models
    return nil unless Setting.gemini_api_key.present?
    Provider::Gemini.list_available_models
  rescue => e
    Rails.logger.error("Failed to fetch Gemini models: #{e.message}")
    Provider::Gemini::FALLBACK_MODELS
  end
end
