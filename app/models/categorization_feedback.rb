class CategorizationFeedback < ApplicationRecord
  belongs_to :family
  belongs_to :txn, class_name: "Transaction"
  belongs_to :suggested_category, class_name: "Category"
  belongs_to :final_category, class_name: "Category", optional: true

  # Delegate transaction methods for convenience
  delegate :date, :amount, :merchant_name, to: :txn, prefix: false

  # Provide a transaction method for convenience (txn is the actual association)
  def transaction
    txn
  end

  # Virtual attribute to determine if the categorization was correct
  # Correct if: suggested == final OR final is null (user didn't change)
  def was_correct?
    final_category_id.nil? || suggested_category_id == final_category_id
  end

  # Scope for feedback within a time window
  scope :last_7_days, -> { where("created_at >= ?", 7.days.ago) }
  scope :last_30_days, -> { where("created_at >= ?", 30.days.ago) }
  scope :all_time, -> { all }

  # Scope for misses (incorrect categorizations)
  scope :misses, -> { where.not(final_category_id: [ nil, :suggested_category_id ]) }

  # Map time window strings to scope symbols
  TIME_WINDOW_MAPPING = {
    "7_days" => :last_7_days,
    "30_days" => :last_30_days,
    "all_time" => :all_time
  }.freeze

  # Calculate accuracy per category for a family and time window
  # Returns hash: { category => { correct: X, total: Y, accuracy: 0.XX } }
  def self.calculate_accuracy_per_category(family, time_window = :last_30_days)
    # Convert string time_window to symbol if needed
    scope_name = time_window.is_a?(String) ? TIME_WINDOW_MAPPING[time_window] || :last_30_days : time_window
    scope = where(family: family).public_send(scope_name)

    results = {}

    # Get distinct category IDs first to avoid GROUP BY issues
    category_ids = scope.distinct.pluck(:suggested_category_id)

    category_ids.each do |category_id|
      total = scope.where(suggested_category_id: category_id).count

      # Correct count: those where final is null (unchanged) or final equals suggested
      correct = scope.where(
        suggested_category_id: category_id
      ).where(
        "final_category_id IS NULL OR final_category_id = suggested_category_id"
      ).count

      # Load category and add to results
      category = Category.find_by(id: category_id)
      next unless category

      results[category] = {
        correct: correct,
        total: total,
        accuracy: total.positive? ? (correct.to_f / total).round(2) : 0.0
      }
    end

    results
  end

  # Recent misses for a specific category
  def self.recent_misses(category, limit: 20)
    misses_by_category = where(suggested_category: category)
      .where.not(final_category_id: [ nil, :suggested_category_id ])
      .includes(:txn, :suggested_category, :final_category)
      .order(created_at: desc)
      .limit(limit)

    misses_by_category.to_a
  end
end
