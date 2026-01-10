require "test_helper"

class LlmUsageTest < ActiveSupport::TestCase
  # OpenAI cost calculation tests

  test "calculates cost for OpenAI gpt-4.1 model" do
    cost = LlmUsage.calculate_cost(model: "gpt-4.1", prompt_tokens: 1000, completion_tokens: 1000)
    # gpt-4.1: $2.00/1M prompt tokens, $8.00/1M completion tokens
    # Expected: (1000 * 2.00 / 1_000_000) + (1000 * 8.00 / 1_000_000) = 0.002 + 0.008 = 0.01
    assert_in_delta 0.01, cost, 0.0001
  end

  test "calculates cost for OpenAI gpt-4.1-mini model" do
    cost = LlmUsage.calculate_cost(model: "gpt-4.1-mini", prompt_tokens: 1000, completion_tokens: 1000)
    # gpt-4.1-mini: $0.40/1M prompt tokens, $1.60/1M completion tokens
    # Expected: (1000 * 0.40 / 1_000_000) + (1000 * 1.60 / 1_000_000) = 0.0004 + 0.0016 = 0.002
    assert_in_delta 0.002, cost, 0.0001
  end

  test "calculates cost for OpenAI gpt-4o model" do
    cost = LlmUsage.calculate_cost(model: "gpt-4o", prompt_tokens: 1000, completion_tokens: 1000)
    # gpt-4o: $2.50/1M prompt tokens, $10.00/1M completion tokens
    # Expected: (1000 * 2.50 / 1_000_000) + (1000 * 10.00 / 1_000_000) = 0.0025 + 0.01 = 0.0125
    assert_in_delta 0.0125, cost, 0.0001
  end

  test "calculates cost for OpenAI gpt-4o-mini model" do
    cost = LlmUsage.calculate_cost(model: "gpt-4o-mini", prompt_tokens: 1000, completion_tokens: 1000)
    # gpt-4o-mini: $0.15/1M prompt tokens, $0.60/1M completion tokens
    # Expected: (1000 * 0.15 / 1_000_000) + (1000 * 0.60 / 1_000_000) = 0.00015 + 0.0006 = 0.00075
    assert_in_delta 0.00075, cost, 0.0001
  end

  test "calculates cost for OpenAI o1-mini model" do
    cost = LlmUsage.calculate_cost(model: "o1-mini", prompt_tokens: 1000, completion_tokens: 1000)
    # o1-mini: $1.10/1M prompt tokens, $4.40/1M completion tokens
    # Expected: (1000 * 1.10 / 1_000_000) + (1000 * 4.40 / 1_000_000) = 0.0011 + 0.0044 = 0.0055
    assert_in_delta 0.0055, cost, 0.0001
  end

  test "calculates cost for OpenAI o1 model" do
    cost = LlmUsage.calculate_cost(model: "o1", prompt_tokens: 1000, completion_tokens: 1000)
    # o1: $15.00/1M prompt tokens, $60.00/1M completion tokens
    # Expected: (1000 * 15.00 / 1_000_000) + (1000 * 60.00 / 1_000_000) = 0.015 + 0.06 = 0.075
    assert_in_delta 0.075, cost, 0.0001
  end

  test "calculates cost for OpenAI gpt-5 model" do
    cost = LlmUsage.calculate_cost(model: "gpt-5", prompt_tokens: 1000, completion_tokens: 1000)
    # gpt-5: $1.25/1M prompt tokens, $10.00/1M completion tokens
    # Expected: (1000 * 1.25 / 1_000_000) + (1000 * 10.00 / 1_000_000) = 0.00125 + 0.01 = 0.01125
    assert_in_delta 0.01125, cost, 0.0001
  end

  test "infers openai provider from gpt-4.1 model name" do
    assert_equal "openai", LlmUsage.infer_provider("gpt-4.1")
  end

  test "infers openai provider from gpt-4.1-mini model name" do
    assert_equal "openai", LlmUsage.infer_provider("gpt-4.1-mini")
  end

  test "infers openai provider from gpt-4o model name" do
    assert_equal "openai", LlmUsage.infer_provider("gpt-4o")
  end

  test "infers openai provider from gpt-4o-mini model name" do
    assert_equal "openai", LlmUsage.infer_provider("gpt-4o-mini")
  end

  test "infers openai provider from o1 model name" do
    assert_equal "openai", LlmUsage.infer_provider("o1")
  end

  test "infers openai provider from o1-mini model name" do
    assert_equal "openai", LlmUsage.infer_provider("o1-mini")
  end

  test "infers openai provider from gpt-5 model name" do
    assert_equal "openai", LlmUsage.infer_provider("gpt-5")
  end

  test "infers openai provider from gpt-5-mini model name" do
    assert_equal "openai", LlmUsage.infer_provider("gpt-5-mini")
  end

  test "infers openai provider from o3 model name" do
    assert_equal "openai", LlmUsage.infer_provider("o3")
  end

  test "returns nil for unknown model without pricing" do
    cost = LlmUsage.calculate_cost(model: "unknown-custom-model", prompt_tokens: 1000, completion_tokens: 1000)
    assert_nil cost
  end

  test "returns openai as default provider for blank model name" do
    assert_equal "openai", LlmUsage.infer_provider("")
    assert_equal "openai", LlmUsage.infer_provider(nil)
  end

  # Anthropic tests (to verify we didn't break Anthropic pricing either)

  test "calculates cost for Anthropic claude-sonnet-4 model" do
    cost = LlmUsage.calculate_cost(model: "claude-sonnet-4", prompt_tokens: 1000, completion_tokens: 1000)
    # claude-sonnet-4: $3.00/1M prompt tokens, $15.00/1M completion tokens
    # Expected: (1000 * 3.00 / 1_000_000) + (1000 * 15.00 / 1_000_000) = 0.003 + 0.015 = 0.018
    assert_in_delta 0.018, cost, 0.0001
  end

  test "infers anthropic provider from claude-sonnet-4 model name" do
    assert_equal "anthropic", LlmUsage.infer_provider("claude-sonnet-4")
  end

  test "infers anthropic provider from claude-haiku-3.5 model name" do
    assert_equal "anthropic", LlmUsage.infer_provider("claude-haiku-3.5")
  end

  # Prefix matching tests

  test "calculates cost for OpenAI model with version suffix using prefix matching" do
    cost = LlmUsage.calculate_cost(model: "gpt-4.1-2024-08-06", prompt_tokens: 1000, completion_tokens: 1000)
    # Should use gpt-4.1 pricing via prefix matching
    assert_in_delta 0.01, cost, 0.0001
  end

  test "estimates auto categorize cost for OpenAI model" do
    # Estimate for 10 transactions, 5 categories
    cost = LlmUsage.estimate_auto_categorize_cost(transaction_count: 10, category_count: 5, model: "gpt-4.1")
    # Base: 150 tokens + transactions: 10 * 100 = 1000 + categories: 5 * 50 = 250
    # Total prompt: 1400 tokens
    # Completion: 10 * 50 = 500 tokens
    # Expected: (1400 * 2.00 / 1_000_000) + (500 * 8.00 / 1_000_000) = 0.0028 + 0.004 = 0.0068
    assert_in_delta 0.0068, cost, 0.0001
  end

  test "estimates auto categorize cost returns 0 for zero transactions" do
    cost = LlmUsage.estimate_auto_categorize_cost(transaction_count: 0, category_count: 5, model: "gpt-4.1")
    assert_equal 0.0, cost
  end
end
