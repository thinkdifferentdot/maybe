require "test_helper"
require "ostruct"

class Settings::HostingsControllerTest < ActionDispatch::IntegrationTest
  include ProviderTestHelper

  setup do
    sign_in users(:family_admin)

    @provider = mock
    Provider::Registry.stubs(:get_provider).with(:synth).returns(@provider)
    @usage_response = provider_success_response(
      OpenStruct.new(
        used: 10,
        limit: 100,
        utilization: 10,
        plan: "free",
      )
    )
  end

  test "cannot edit when self hosting is disabled" do
    with_env_overrides SELF_HOSTED: "false" do
      get settings_hosting_url
      assert_response :forbidden

      patch settings_hosting_url, params: { setting: { require_invite_for_signup: true } }
      assert_response :forbidden
    end
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
      patch settings_hosting_url, params: { setting: { synth_api_key: "1234567890" } }

      assert_equal "1234567890", Setting.synth_api_key
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

  test "can update supabase_url setting" do
    with_self_hosting do
      patch settings_hosting_url, params: {
        setting: { supabase_url: "https://new-project.supabase.co" }
      }

      assert_redirected_to settings_hosting_path
      assert_equal "https://new-project.supabase.co", Setting.supabase_url
    end
  end

  test "can update supabase_key setting" do
    with_self_hosting do
      patch settings_hosting_url, params: {
        setting: { supabase_key: "new-secret-key-123" }
      }

      assert_redirected_to settings_hosting_path
      assert_equal "new-secret-key-123", Setting.supabase_key
    end
  end

  test "can update lunchflow_api_key setting" do
    with_self_hosting do
      patch settings_hosting_url, params: {
        setting: { lunchflow_api_key: "lf-new-key-456" }
      }

      assert_redirected_to settings_hosting_path
      assert_equal "lf-new-key-456", Setting.lunchflow_api_key
    end
  end

  test "can update multiple lunchflow settings at once" do
    with_self_hosting do
      patch settings_hosting_url, params: {
        setting: {
          supabase_url: "https://multi.supabase.co",
          supabase_key: "multi-key",
          lunchflow_api_key: "multi-lf-key"
        }
      }

      assert_redirected_to settings_hosting_path
      assert_equal "https://multi.supabase.co", Setting.supabase_url
      assert_equal "multi-key", Setting.supabase_key
      assert_equal "multi-lf-key", Setting.lunchflow_api_key
    end
  end
end
