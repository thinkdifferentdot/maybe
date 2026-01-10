class Settings::AutoCategorizationController < ApplicationController
  layout "settings"

  before_action :ensure_admin

  def show
    @breadcrumbs = [
      [ "Home", root_path ],
      [ "Auto-Categorization", nil ]
    ]
  end

  def update
    if auto_categorization_params.key?(:ai_categorize_on_import)
      Setting.ai_categorize_on_import = auto_categorization_params[:ai_categorize_on_import]
    end

    if auto_categorization_params.key?(:ai_categorize_on_sync)
      Setting.ai_categorize_on_sync = auto_categorization_params[:ai_categorize_on_sync]
    end

    if auto_categorization_params.key?(:ai_categorize_on_ui_action)
      Setting.ai_categorize_on_ui_action = auto_categorization_params[:ai_categorize_on_ui_action]
    end

    redirect_to settings_auto_categorization_path, notice: t(".success")
  end

  private

    def auto_categorization_params
      params.require(:setting).permit(:ai_categorize_on_import, :ai_categorize_on_sync, :ai_categorize_on_ui_action)
    end

    def ensure_admin
      redirect_to settings_auto_categorization_path, alert: t(".not_authorized") unless Current.user&.admin?
    end
end
