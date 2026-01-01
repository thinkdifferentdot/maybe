# Dynamic settings the user can change within the app (helpful for self-hosting)
class Setting < RailsSettings::Base
  cache_prefix { "v1" }

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
end
