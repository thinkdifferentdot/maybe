# Dynamic settings the user can change within the app (helpful for self-hosting)
class Setting < RailsSettings::Base
  cache_prefix { "v2" }

  field :synth_api_key, type: :string, default: ENV["SYNTH_API_KEY"]
  field :openai_access_token, type: :string, default: ENV["OPENAI_ACCESS_TOKEN"]
  field :gemini_api_key, type: :string, default: ENV["GEMINI_API_KEY"]
  field :anthropic_api_key, type: :string, default: ENV["ANTHROPIC_API_KEY"]

  field :preferred_llm_provider, type: :string, default: "openai"

  # Lunchflow-Supabase integration settings
  field :supabase_url, type: :string, default: ENV["SUPABASE_URL"]
  field :supabase_key, type: :string, default: ENV["SUPABASE_SERVICE_ROLE_KEY"]
  field :lunchflow_api_key, type: :string, default: ENV["LUNCHFLOW_API_KEY"]

  field :require_invite_for_signup, type: :boolean, default: false
  field :require_email_confirmation, type: :boolean, default: ENV.fetch("REQUIRE_EMAIL_CONFIRMATION", "true") == "true"

  # Auto-Categorization Settings
  field :openai_categorization_model, type: :string, default: ENV.fetch("OPENAI_CATEGORIZATION_MODEL", "gpt-4o-mini")
  field :anthropic_categorization_model, type: :string, default: ENV.fetch("ANTHROPIC_CATEGORIZATION_MODEL", "claude-3-5-sonnet-20241022")
  field :gemini_categorization_model, type: :string, default: ENV.fetch("GEMINI_CATEGORIZATION_MODEL", "gemini-2.0-flash-exp")

  field :categorization_confidence_threshold, type: :integer, default: 60
  field :categorization_batch_size, type: :integer, default: 50
  field :categorization_prefer_subcategories, type: :boolean, default: true
  field :categorization_enforce_classification_match, type: :boolean, default: true
  field :categorization_null_tolerance, type: :string, default: "pessimistic"

  validates :categorization_confidence_threshold,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :categorization_batch_size,
            numericality: { only_integer: true, greater_than_or_equal_to: 10, less_than_or_equal_to: 200 }
  validates :categorization_null_tolerance,
            inclusion: { in: %w[pessimistic balanced optimistic] }
  validates :openai_categorization_model,
            presence: true, if: -> { Setting.openai_access_token.present? }
  validates :anthropic_categorization_model,
            presence: true, if: -> { Setting.anthropic_api_key.present? }
  validates :gemini_categorization_model,
            presence: true, if: -> { Setting.gemini_api_key.present? }
end
