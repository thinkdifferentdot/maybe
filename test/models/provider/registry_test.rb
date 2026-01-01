require "test_helper"

class Provider::RegistryTest < ActiveSupport::TestCase
  setup do
    Setting.gemini_api_key = nil
    Setting.anthropic_api_key = nil
    Setting.openai_access_token = nil
    ENV["GEMINI_API_KEY"] = nil
    ENV["ANTHROPIC_API_KEY"] = nil
    ENV["OPENAI_ACCESS_TOKEN"] = nil
  end

  test "returns available providers based on api keys" do
    Setting.gemini_api_key = "test_key"

    providers = Provider::Registry.for_concept(:llm).providers
    assert_equal 1, providers.count
    assert_instance_of Provider::Gemini, providers.first
  end

  test "respects preferred provider order" do
    Setting.gemini_api_key = "gemini_key"
    Setting.anthropic_api_key = "anthropic_key"
    Setting.openai_access_token = "openai_key"

    Setting.preferred_llm_provider = "gemini"

    providers = Provider::Registry.for_concept(:llm).providers
    assert_instance_of Provider::Gemini, providers.first
    assert_equal 3, providers.count

    Setting.preferred_llm_provider = "anthropic"
    providers = Provider::Registry.for_concept(:llm).providers
    assert_instance_of Provider::Anthropic, providers.first

    Setting.preferred_llm_provider = "openai"
    providers = Provider::Registry.for_concept(:llm).providers
    assert_instance_of Provider::Openai, providers.first
  end

  test "falls back if preferred provider is not configured" do
    Setting.gemini_api_key = "gemini_key"
    Setting.preferred_llm_provider = "anthropic" # Not configured

    providers = Provider::Registry.for_concept(:llm).providers
    assert_instance_of Provider::Gemini, providers.first
  end
end
