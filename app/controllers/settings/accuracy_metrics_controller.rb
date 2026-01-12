class Settings::AccuracyMetricsController < ApplicationController
  layout "settings"

  before_action :ensure_admin

  TIME_WINDOWS = %w[7_days 30_days all_time].freeze

  def show
    @time_window = params[:time_window].presence.in?(TIME_WINDOWS) ? params[:time_window] : "30_days"
    @category_metrics = CategorizationFeedback.calculate_accuracy_per_category(Current.family, @time_window)
    @selected_category_id = params[:category_id]
    @recent_misses = @selected_category_id ? recent_misses_for_category : []

    @breadcrumbs = [
      [ t(".home"), root_path ],
      [ t(".page_title"), nil ]
    ]
  end

  private

    def ensure_admin
      redirect_to settings_auto_categorization_path, alert: t(".not_authorized") unless Current.user&.admin?
    end

    def recent_misses_for_category
      return [] unless @selected_category_id

      category = Current.family.categories.find_by(id: @selected_category_id)
      return [] unless category

      CategorizationFeedback.recent_misses(category)
    end
end
