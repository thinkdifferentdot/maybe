class Settings::HostingsController < ApplicationController
  layout "settings"

  guard_feature unless: -> { self_hosted? }

  before_action :ensure_admin, only: [ :update, :clear_cache, :anthropic_models ]

  def show
    @breadcrumbs = [
      [ "Home", root_path ],
      [ "Self-Hosting", nil ]
    ]

    # Determine which providers are currently selected
    exchange_rate_provider = ENV["EXCHANGE_RATE_PROVIDER"].presence || Setting.exchange_rate_provider
    securities_provider = ENV["SECURITIES_PROVIDER"].presence || Setting.securities_provider

    # Show Twelve Data settings if either provider is set to twelve_data
    @show_twelve_data_settings = exchange_rate_provider == "twelve_data" || securities_provider == "twelve_data"

    # Show Yahoo Finance settings if either provider is set to yahoo_finance
    @show_yahoo_finance_settings = exchange_rate_provider == "yahoo_finance" || securities_provider == "yahoo_finance"

    # Get current LLM provider for initial visibility state
    @llm_provider = ENV["LLM_PROVIDER"].presence || Setting.llm_provider

    # Only fetch provider data if we're showing the section
    if @show_twelve_data_settings
      twelve_data_provider = Provider::Registry.get_provider(:twelve_data)
      @twelve_data_usage = twelve_data_provider&.usage
    end

    if @show_yahoo_finance_settings
      @yahoo_finance_provider = Provider::Registry.get_provider(:yahoo_finance)
    end
  end

  def update
    if hosting_params.key?(:onboarding_state)
      onboarding_state = hosting_params[:onboarding_state].to_s
      Setting.onboarding_state = onboarding_state
    end

    if hosting_params.key?(:require_email_confirmation)
      Setting.require_email_confirmation = hosting_params[:require_email_confirmation]
    end

    if hosting_params.key?(:brand_fetch_client_id)
      Setting.brand_fetch_client_id = hosting_params[:brand_fetch_client_id]
    end

    if hosting_params.key?(:twelve_data_api_key)
      Setting.twelve_data_api_key = hosting_params[:twelve_data_api_key]
    end

    if hosting_params.key?(:exchange_rate_provider)
      Setting.exchange_rate_provider = hosting_params[:exchange_rate_provider]
    end

    if hosting_params.key?(:securities_provider)
      Setting.securities_provider = hosting_params[:securities_provider]
    end

    if hosting_params.key?(:openai_access_token)
      token_param = hosting_params[:openai_access_token].to_s.strip
      # Ignore blanks and redaction placeholders to prevent accidental overwrite
      unless token_param.blank? || token_param == "********"
        Setting.openai_access_token = token_param
      end
    end

    # Validate OpenAI configuration before updating
    if hosting_params.key?(:openai_uri_base) || hosting_params.key?(:openai_model)
      Setting.validate_openai_config!(
        uri_base: hosting_params[:openai_uri_base],
        model: hosting_params[:openai_model]
      )
    end

    if hosting_params.key?(:openai_uri_base)
      Setting.openai_uri_base = hosting_params[:openai_uri_base]
    end

    if hosting_params.key?(:openai_model)
      Setting.openai_model = hosting_params[:openai_model]
    end

    if hosting_params.key?(:openai_json_mode)
      Setting.openai_json_mode = hosting_params[:openai_json_mode].presence
    end

    if hosting_params.key?(:anthropic_access_token)
      token_param = hosting_params[:anthropic_access_token].to_s.strip
      # Ignore blanks and redaction placeholders to prevent accidental overwrite
      unless token_param.blank? || token_param == "********"
        Setting.anthropic_access_token = token_param
      end
    end

    # Validate Anthropic configuration before updating
    if hosting_params.key?(:anthropic_model)
      Setting.validate_anthropic_config!(model: hosting_params[:anthropic_model])
      Setting.anthropic_model = hosting_params[:anthropic_model]
    end

    if hosting_params.key?(:llm_provider)
      Setting.validate_llm_provider!(hosting_params[:llm_provider])
      Setting.llm_provider = hosting_params[:llm_provider]
    end

    redirect_to settings_hosting_path, notice: t(".success")
  rescue Setting::ValidationError => error
    flash.now[:alert] = error.message
    render :show, status: :unprocessable_entity
  end

  def clear_cache
    DataCacheClearJob.perform_later(Current.family)
    redirect_to settings_hosting_path, notice: t(".cache_cleared")
  end

  def anthropic_models
    models = []
    error = nil

    access_token = ENV["ANTHROPIC_API_KEY"].presence || Setting.anthropic_access_token

    if access_token.blank?
      error = I18n.t("settings.hostings.anthropic_settings.models_fetch_error_no_key")
    else
      begin
        client = ::Anthropic::Client.new(api_key: access_token)
        response = client.models.list(limit: 100)

        # Convert response to array of model hashes
        # The response is a Page object that can be iterated
        response.to_a.each do |model|
          # Only include claude- models (the ones supported by our system)
          if model.id.start_with?("claude-")
            models << {
              id: model.id,
              display_name: model.display_name || model.id
            }
          end
        end
      rescue ::Anthropic::Errors::NotFoundError => e
        error = I18n.t("settings.hostings.anthropic_settings.models_fetch_error_invalid_key")
      rescue ::Anthropic::Errors::AuthenticationError => e
        error = I18n.t("settings.hostings.anthropic_settings.models_fetch_error_invalid_key")
      rescue => e
        Rails.logger.error("Failed to fetch Anthropic models: #{e.class} - #{e.message}")
        error = I18n.t("settings.hostings.anthropic_settings.models_fetch_error", error: e.message)
      end
    end

    render json: { models: models, error: error }
  end

  private
    def hosting_params
      params.require(:setting).permit(:onboarding_state, :require_email_confirmation, :brand_fetch_client_id, :twelve_data_api_key, :openai_access_token, :openai_uri_base, :openai_model, :openai_json_mode, :exchange_rate_provider, :securities_provider, :anthropic_access_token, :anthropic_model, :llm_provider)
    end

    def ensure_admin
      redirect_to settings_hosting_path, alert: t(".not_authorized") unless Current.user.admin?
    end
end
