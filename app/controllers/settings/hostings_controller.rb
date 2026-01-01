class Settings::HostingsController < ApplicationController
  layout "settings"

  guard_feature unless: -> { self_hosted? }

  before_action :ensure_admin, only: :clear_cache

  def show
    synth_provider = Provider::Registry.get_provider(:synth)
    @synth_usage = synth_provider&.usage
  end

  def update
    if hosting_params.key?(:require_invite_for_signup)
      Setting.require_invite_for_signup = hosting_params[:require_invite_for_signup]
    end

    if hosting_params.key?(:require_email_confirmation)
      Setting.require_email_confirmation = hosting_params[:require_email_confirmation]
    end

    if hosting_params.key?(:synth_api_key)
      Setting.synth_api_key = hosting_params[:synth_api_key]
    end

    # LLM Settings
    if hosting_params.key?(:openai_access_token)
      Setting.openai_access_token = hosting_params[:openai_access_token]
    end

    if hosting_params.key?(:gemini_api_key)
      Setting.gemini_api_key = hosting_params[:gemini_api_key]
    end

    if hosting_params.key?(:anthropic_api_key)
      Setting.anthropic_api_key = hosting_params[:anthropic_api_key]
    end

    if hosting_params.key?(:preferred_llm_provider)
      Setting.preferred_llm_provider = hosting_params[:preferred_llm_provider]
    end

    # Lunchflow-Supabase settings
    if hosting_params.key?(:supabase_url)
      Setting.supabase_url = hosting_params[:supabase_url]
    end

    if hosting_params.key?(:supabase_key)
      Setting.supabase_key = hosting_params[:supabase_key]
    end

    if hosting_params.key?(:lunchflow_api_key)
      Setting.lunchflow_api_key = hosting_params[:lunchflow_api_key]
    end

    redirect_to settings_hosting_path, notice: t(".success")
  rescue ActiveRecord::RecordInvalid => error
    flash.now[:alert] = t(".failure")
    render :show, status: :unprocessable_entity
  end

  def clear_cache
    DataCacheClearJob.perform_later(Current.family)
    redirect_to settings_hosting_path, notice: t(".cache_cleared")
  end

  private
    def hosting_params
      params.require(:setting).permit(
        :require_invite_for_signup,
        :require_email_confirmation,
        :synth_api_key,
        :openai_access_token,
        :gemini_api_key,
        :anthropic_api_key,
        :preferred_llm_provider,
        :supabase_url,
        :supabase_key,
        :lunchflow_api_key
      )
    end

    def ensure_admin
      redirect_to settings_hosting_path, alert: t(".not_authorized") unless Current.user.admin?
    end
end
