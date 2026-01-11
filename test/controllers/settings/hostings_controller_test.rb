require "test_helper"
require "ostruct"

class Settings::HostingsControllerTest < ActionDispatch::IntegrationTest
  include ProviderTestHelper

  setup do
    sign_in users(:family_admin)

    @provider = mock
    Provider::Registry.stubs(:get_provider).with(:twelve_data).returns(@provider)

    @provider.stubs(:healthy?).returns(true)
    Provider::Registry.stubs(:get_provider).with(:yahoo_finance).returns(@provider)
    @provider.stubs(:usage).returns(provider_success_response(
      OpenStruct.new(
        used: 10,
        limit: 100,
        utilization: 10,
        plan: "free",
      )
    ))

    # Clear any existing anthropic settings to avoid test interference
    Setting.where(var: "anthropic_access_token").destroy_all
    Setting.clear_cache
  end

  test "cannot edit when self hosting is disabled" do
    @provider.stubs(:usage).returns(@usage_response)

    Rails.configuration.stubs(:app_mode).returns("managed".inquiry)
    get settings_hosting_url
    assert_response :forbidden

    patch settings_hosting_url, params: { setting: { onboarding_state: "invite_only" } }
    assert_response :forbidden
  end

  test "should get edit when self hosting is enabled" do
    @provider.expects(:usage).returns(@usage_response)

    with_self_hosting do
      get settings_hosting_url
      assert_response :success
    end
  end

  test "can update settings when self hosting is enabled" do
    with_self_hosting do
      patch settings_hosting_url, params: { setting: { twelve_data_api_key: "1234567890" } }

      assert_equal "1234567890", Setting.twelve_data_api_key
    end
  end

  test "can update onboarding state when self hosting is enabled" do
    with_self_hosting do
      patch settings_hosting_url, params: { setting: { onboarding_state: "invite_only" } }

      assert_equal "invite_only", Setting.onboarding_state
      assert Setting.require_invite_for_signup

      patch settings_hosting_url, params: { setting: { onboarding_state: "closed" } }

      assert_equal "closed", Setting.onboarding_state
      refute Setting.require_invite_for_signup
    end
  end

  test "can update openai access token when self hosting is enabled" do
    with_self_hosting do
      patch settings_hosting_url, params: { setting: { openai_access_token: "token" } }

      assert_equal "token", Setting.openai_access_token
    end
  end

  test "can update openai uri base and model together when self hosting is enabled" do
    with_self_hosting do
      patch settings_hosting_url, params: { setting: { openai_uri_base: "https://api.example.com/v1", openai_model: "gpt-4" } }

      assert_equal "https://api.example.com/v1", Setting.openai_uri_base
      assert_equal "gpt-4", Setting.openai_model
    end
  end

  test "cannot update openai uri base without model when self hosting is enabled" do
    with_self_hosting do
      Setting.openai_model = ""

      patch settings_hosting_url, params: { setting: { openai_uri_base: "https://api.example.com/v1" } }

      assert_response :unprocessable_entity
      assert_match(/OpenAI model is required/, flash[:alert])
      assert_nil Setting.openai_uri_base
    end
  end

  test "can update openai model alone when self hosting is enabled" do
    with_self_hosting do
      patch settings_hosting_url, params: { setting: { openai_model: "gpt-4" } }

      assert_equal "gpt-4", Setting.openai_model
    end
  end

  test "cannot clear openai model when custom uri base is set" do
    with_self_hosting do
      Setting.openai_uri_base = "https://api.example.com/v1"
      Setting.openai_model = "gpt-4"

      patch settings_hosting_url, params: { setting: { openai_model: "" } }

      assert_response :unprocessable_entity
      assert_match(/OpenAI model is required/, flash[:alert])
      assert_equal "gpt-4", Setting.openai_model
    end
  end

  test "can clear data cache when self hosting is enabled" do
    account = accounts(:investment)
    holding = account.holdings.first
    exchange_rate = exchange_rates(:one)
    security_price = holding.security.prices.first
    account_balance = account.balances.create!(date: Date.current, balance: 1000, currency: "USD")

    with_self_hosting do
      perform_enqueued_jobs(only: DataCacheClearJob) do
        delete clear_cache_settings_hosting_url
      end
    end

    assert_redirected_to settings_hosting_url
    assert_equal I18n.t("settings.hostings.clear_cache.cache_cleared"), flash[:notice]

    assert_not ExchangeRate.exists?(exchange_rate.id)
    assert_not Security::Price.exists?(security_price.id)
    assert_not Holding.exists?(holding.id)
    assert_not Balance.exists?(account_balance.id)
  end

  test "can clear data only when admin" do
    with_self_hosting do
      sign_in users(:family_member)

      assert_no_enqueued_jobs do
        delete clear_cache_settings_hosting_url
      end

      assert_redirected_to settings_hosting_url
      assert_equal I18n.t("settings.hostings.not_authorized"), flash[:alert]
    end
  end

  test "can update anthropic_access_token" do
    with_self_hosting do
      patch settings_hosting_url, params: { setting: { anthropic_access_token: "test-token" } }

      assert_redirected_to settings_hosting_url
      assert_equal "test-token", Setting.anthropic_access_token
    end
  end

  test "can update anthropic_model" do
    with_self_hosting do
      patch settings_hosting_url, params: { setting: { anthropic_model: "claude-opus-4-5" } }

      assert_redirected_to settings_hosting_url
      assert_equal "claude-opus-4-5", Setting.anthropic_model
    end
  end

  test "can update llm_provider" do
    with_self_hosting do
      patch settings_hosting_url, params: { setting: { llm_provider: "anthropic" } }

      assert_redirected_to settings_hosting_url
      assert_equal "anthropic", Setting.llm_provider
    end
  end

  test "invalid llm_provider shows error" do
    with_self_hosting do
      patch settings_hosting_url, params: { setting: { llm_provider: "invalid" } }

      assert_response :unprocessable_entity
      assert_match(/LLM provider must be one of/, flash[:alert])
    end
  end

  test "redaction placeholder preserves existing anthropic_access_token" do
    with_self_hosting do
      Setting.anthropic_access_token = "existing-token"

      patch settings_hosting_url, params: { setting: { anthropic_access_token: "********" } }

      assert_redirected_to settings_hosting_url
      assert_equal "existing-token", Setting.anthropic_access_token
    end
  end

  test "invalid anthropic model shows error" do
    with_self_hosting do
      patch settings_hosting_url, params: { setting: { anthropic_model: "gpt-4" } }

      assert_response :unprocessable_entity
      assert_match(/must start with/, flash[:alert])
    end
  end

  test "admin can fetch anthropic models with valid api key" do
    with_self_hosting do
      with_env_overrides("ANTHROPIC_API_KEY" => nil) do
        Setting.where(var: "anthropic_access_token").destroy_all
        Setting.clear_cache
        Setting.anthropic_access_token = "test-api-key"

        mock_client = mock
        mock_page = mock
        mock_models = [
          OpenStruct.new(id: "claude-opus-4-5-20251101", display_name: "Claude Opus 4.5"),
          OpenStruct.new(id: "claude-sonnet-4-5-20250929", display_name: "Claude Sonnet 4.5"),
          OpenStruct.new(id: "claude-haiku-4-5-20251001", display_name: "Claude Haiku 4.5")
        ]

        mock_page.expects(:to_a).returns(mock_models)
        mock_client.expects(:models).returns(mock("list" => mock_page))
        ::Anthropic::Client.expects(:new).with(api_key: "test-api-key").returns(mock_client)

        get anthropic_models_settings_hosting_url

        assert_response :success
        json_response = JSON.parse(response.body)

        assert json_response["models"].is_a?(Array)
        assert_equal 3, json_response["models"].length
        assert_equal "claude-opus-4-5-20251101", json_response["models"][0]["id"]
        assert_equal "Claude Opus 4.5", json_response["models"][0]["display_name"]
        assert_nil json_response["error"]
      end
    end
  end

  test "non-admin cannot fetch anthropic models" do
    with_self_hosting do
      sign_in users(:family_member)

      get anthropic_models_settings_hosting_url

      assert_redirected_to settings_hosting_url
      assert_equal I18n.t("settings.hostings.not_authorized"), flash[:alert]
    end
  end

  test "anthropic models endpoint returns error when no api key" do
    with_self_hosting do
      # Note: The controller checks ENV first, then Setting
      # We can't fully override ENV in tests due to dotenv-rails loading .env before Rails boots
      # So we mock the client to simulate a connection error (as if there's no valid key)
      Setting.clear_cache

      mock_client = mock
      mock_client.expects(:models).raises(StandardError.new("Connection error"))
      ::Anthropic::Client.expects(:new).returns(mock_client)

      get anthropic_models_settings_hosting_url

      assert_response :success
      json_response = JSON.parse(response.body)

      assert_equal [], json_response["models"]
      # When API call fails for any reason (including no/bad key), we show generic error
      assert_equal "Failed to load models: Connection error", json_response["error"]
    end
  end

  test "anthropic models endpoint returns error when invalid api key" do
    with_self_hosting do
      with_env_overrides("ANTHROPIC_API_KEY" => nil) do
        Setting.where(var: "anthropic_access_token").destroy_all
        Setting.clear_cache
        Setting.anthropic_access_token = "invalid-key"

        url = URI("https://api.anthropic.com/v1/models")
        auth_error = ::Anthropic::Errors::AuthenticationError.new(
          url: url,
          status: 401,
          headers: {},
          body: nil,
          request: nil,
          response: nil,
          message: "Invalid API key"
        )
        mock_client = mock
        mock_client.expects(:models).raises(auth_error)
        ::Anthropic::Client.expects(:new).with(api_key: "invalid-key").returns(mock_client)

        get anthropic_models_settings_hosting_url

        assert_response :success
        json_response = JSON.parse(response.body)

        assert_equal [], json_response["models"]
        assert_equal "Invalid API key", json_response["error"]
      end
    end
  end

  test "anthropic models endpoint uses env key when setting is blank" do
    with_self_hosting do
      with_env_overrides("ANTHROPIC_API_KEY" => "env-api-key") do
        Setting.where(var: "anthropic_access_token").destroy_all
        Setting.clear_cache

        mock_client = mock
        mock_page = mock
        mock_models = [
          OpenStruct.new(id: "claude-sonnet-4-5-20250929", display_name: "Claude Sonnet 4.5")
        ]

        mock_page.expects(:to_a).returns(mock_models)
        mock_client.expects(:models).returns(mock("list" => mock_page))
        ::Anthropic::Client.expects(:new).with(api_key: "env-api-key").returns(mock_client)

        get anthropic_models_settings_hosting_url

        assert_response :success
        json_response = JSON.parse(response.body)

        assert json_response["models"].is_a?(Array)
        assert_equal 1, json_response["models"].length
      end
    end
  end

  test "anthropic models endpoint filters non-claude models" do
    with_self_hosting do
      with_env_overrides("ANTHROPIC_API_KEY" => nil) do
        Setting.where(var: "anthropic_access_token").destroy_all
        Setting.clear_cache
        Setting.anthropic_access_token = "test-api-key"

        mock_client = mock
        mock_page = mock
        # Mix of claude and non-claude models
        mock_models = [
          OpenStruct.new(id: "claude-opus-4-5-20251101", display_name: "Claude Opus 4.5"),
          OpenStruct.new(id: "some-other-model", display_name: "Some Other Model"),
          OpenStruct.new(id: "claude-sonnet-4-5-20250929", display_name: "Claude Sonnet 4.5")
        ]

        mock_page.expects(:to_a).returns(mock_models)
        mock_client.expects(:models).returns(mock("list" => mock_page))
        ::Anthropic::Client.expects(:new).with(api_key: "test-api-key").returns(mock_client)

        get anthropic_models_settings_hosting_url

        assert_response :success
        json_response = JSON.parse(response.body)

        # Only claude- models should be included
        assert_equal 2, json_response["models"].length
        json_response["models"].each do |model|
          assert_match(/^claude-/, model["id"])
        end
      end
    end
  end

  test "anthropic models endpoint handles generic errors" do
    with_self_hosting do
      with_env_overrides("ANTHROPIC_API_KEY" => nil) do
        Setting.where(var: "anthropic_access_token").destroy_all
        Setting.clear_cache
        Setting.anthropic_access_token = "test-api-key"

        mock_client = mock
        mock_client.expects(:models).raises(StandardError.new("Network error"))
        ::Anthropic::Client.expects(:new).with(api_key: "test-api-key").returns(mock_client)

        get anthropic_models_settings_hosting_url

        assert_response :success
        json_response = JSON.parse(response.body)

        assert_equal [], json_response["models"]
        assert_equal "Failed to load models: Network error", json_response["error"]
      end
    end
  end
end
