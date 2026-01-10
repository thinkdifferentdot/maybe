require "test_helper"

class Provider::RegistryTest < ActiveSupport::TestCase
  test "providers filters out nil values when provider is not configured" do
    # Ensure OpenAI and Anthropic are not configured
    ClimateControl.modify("OPENAI_ACCESS_TOKEN" => nil, "ANTHROPIC_API_KEY" => nil) do
      Setting.stubs(:openai_access_token).returns(nil)
      Setting.stubs(:anthropic_access_token).returns(nil)

      registry = Provider::Registry.for_concept(:llm)

      # Should return empty array instead of [nil]
      assert_equal [], registry.providers
    end
  end

  test "providers returns configured providers" do
    # Mock a configured OpenAI provider
    mock_provider = mock("openai_provider")
    Provider::Registry.stubs(:openai).returns(mock_provider)
    Provider::Registry.stubs(:anthropic).returns(nil)

    registry = Provider::Registry.for_concept(:llm)

    assert_equal [ mock_provider ], registry.providers
  end

  test "get_provider raises error when provider not found for concept" do
    registry = Provider::Registry.for_concept(:llm)

    error = assert_raises(Provider::Registry::Error) do
      registry.get_provider(:nonexistent)
    end

    assert_match(/Provider 'nonexistent' not found for concept: llm/, error.message)
  end

  test "get_provider returns nil when provider not configured" do
    # Ensure OpenAI is not configured
    ClimateControl.modify("OPENAI_ACCESS_TOKEN" => nil) do
      Setting.stubs(:openai_access_token).returns(nil)

      registry = Provider::Registry.for_concept(:llm)

      # Should return nil when provider method exists but returns nil
      assert_nil registry.get_provider(:openai)
    end
  end

  test "openai provider falls back to Setting when ENV is empty string" do
    # Mock ENV to return empty string (common in Docker/env files)
    # Use stub_env helper which properly stubs ENV access
    ClimateControl.modify(
      "OPENAI_ACCESS_TOKEN" => "",
      "OPENAI_URI_BASE" => "",
      "OPENAI_MODEL" => ""
    ) do
      Setting.stubs(:openai_access_token).returns("test-token-from-setting")
      Setting.stubs(:openai_uri_base).returns(nil)
      Setting.stubs(:openai_model).returns(nil)

      provider = Provider::Registry.get_provider(:openai)

      # Should successfully create provider using Setting value
      assert_not_nil provider
      assert_instance_of Provider::Openai, provider
    end
  end

  # LLM provider selection tests
  test "llm concept includes both openai and anthropic in providers" do
    # Test that both providers are available through the registry
    ClimateControl.modify("OPENAI_ACCESS_TOKEN" => nil, "ANTHROPIC_API_KEY" => nil) do
      Setting.stubs(:openai_access_token).returns("test-openai-key")
      Setting.stubs(:anthropic_access_token).returns("test-anthropic-key")
      Setting.stubs(:anthropic_model).returns("claude-sonnet-4-5-20250929")

      registry = Provider::Registry.for_concept(:llm)
      providers = registry.providers

      # Both providers should be returned when configured
      assert_equal 2, providers.length
      provider_classes = providers.map { |p| p.class }
      assert_includes provider_classes, Provider::Openai
      assert_includes provider_classes, Provider::Anthropic
    end
  end

  test "get_provider returns Provider::Anthropic when configured" do
    ClimateControl.modify("ANTHROPIC_API_KEY" => nil) do
      Setting.stubs(:anthropic_access_token).returns("test-anthropic-key")
      Setting.stubs(:anthropic_model).returns("claude-sonnet-4-5-20250929")

      provider = Provider::Registry.get_provider(:anthropic)

      assert_not_nil provider
      assert_instance_of Provider::Anthropic, provider
    end
  end

  test "get_provider returns nil when anthropic not configured" do
    ClimateControl.modify("ANTHROPIC_API_KEY" => nil) do
      Setting.stubs(:anthropic_access_token).returns(nil)

      provider = Provider::Registry.get_provider(:anthropic)

      assert_nil provider
    end
  end

  test "get_provider returns Provider::Openai when configured" do
    ClimateControl.modify("OPENAI_ACCESS_TOKEN" => nil) do
      Setting.stubs(:openai_access_token).returns("test-openai-key")

      provider = Provider::Registry.get_provider(:openai)

      assert_not_nil provider
      assert_instance_of Provider::Openai, provider
    end
  end

  test "get_provider returns nil when openai not configured" do
    ClimateControl.modify("OPENAI_ACCESS_TOKEN" => nil) do
      Setting.stubs(:openai_access_token).returns(nil)

      provider = Provider::Registry.get_provider(:openai)

      assert_nil provider
    end
  end
end
