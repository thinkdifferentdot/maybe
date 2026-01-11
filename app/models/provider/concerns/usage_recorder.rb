# frozen_string_literal: true

# Shared usage recording concern for all LLM providers
# Handles both Hash-based (OpenAI) and BaseModel-based (Anthropic) usage data formats
module Provider::Concerns::UsageRecorder
  extend ActiveSupport::Concern

  private

    # Records LLM usage for a family
    # Handles both Hash (OpenAI) and BaseModel (Anthropic) usage data formats
    # Automatically infers provider from model name
    # Returns nil if pricing is unavailable (e.g., custom/self-hosted models)
    def record_usage(model_name, usage_data, operation:, metadata: {})
      return unless family && usage_data

      # Extract tokens based on format (Hash vs BaseModel)
      prompt_tokens, completion_tokens = extract_tokens(usage_data)
      total_tokens = prompt_tokens + completion_tokens

      estimated_cost = LlmUsage.calculate_cost(
        model: model_name,
        prompt_tokens: prompt_tokens,
        completion_tokens: completion_tokens
      )

      # Log when we can't estimate the cost (e.g., custom/self-hosted models)
      if estimated_cost.nil?
        Rails.logger.info("Recording LLM usage without cost estimate for unknown model: #{model_name}")
      end

      inferred_provider = LlmUsage.infer_provider(model_name)
      family.llm_usages.create!(
        provider: inferred_provider,
        model: model_name,
        operation: operation,
        prompt_tokens: prompt_tokens,
        completion_tokens: completion_tokens,
        total_tokens: total_tokens,
        estimated_cost: estimated_cost,
        metadata: metadata
      )

      Rails.logger.info("LLM usage recorded - Operation: #{operation}, Cost: #{estimated_cost.inspect}")
    rescue => e
      Rails.logger.error("Failed to record LLM usage: #{e.message}")
    end

    # Extract tokens from different usage data formats
    # - Anthropic::Models::Usage (BaseModel): responds to input_tokens/output_tokens
    # - Hash (OpenAI API response): has "prompt_tokens"/"input_tokens" and "completion_tokens"/"output_tokens" keys
    def extract_tokens(usage_data)
      if usage_data.respond_to?(:input_tokens)
        # Anthropic::Models::Usage BaseModel (and similar)
        [usage_data.input_tokens, usage_data.output_tokens]
      else
        # Hash (OpenAI API response) - handle both old and new key names
        prompt = usage_data["prompt_tokens"] || usage_data["input_tokens"] || 0
        completion = usage_data["completion_tokens"] || usage_data["output_tokens"] || 0
        [prompt, completion]
      end
    end

    # Records failed LLM usage for a family with error details
    def record_usage_error(model_name, operation:, error:, metadata: {})
      return unless family

      Rails.logger.info("Recording failed LLM usage - Operation: #{operation}, Error: #{error.message}")

      # Extract HTTP status code if available from the error
      http_status_code = extract_http_status_code(error)

      error_metadata = metadata.merge(
        error: error.message,
        http_status_code: http_status_code
      )

      inferred_provider = LlmUsage.infer_provider(model_name)
      family.llm_usages.create!(
        provider: inferred_provider,
        model: model_name,
        operation: operation,
        prompt_tokens: 0,
        completion_tokens: 0,
        total_tokens: 0,
        estimated_cost: nil,
        metadata: error_metadata
      )

      Rails.logger.info("Failed LLM usage recorded - Operation: #{operation}, Status: #{http_status_code}")
    rescue => e
      Rails.logger.error("Failed to record LLM usage error: #{e.message}")
    end

    def extract_http_status_code(error)
      # Try to extract HTTP status code from various error types
      if error.respond_to?(:code)
        error.code
      elsif error.respond_to?(:http_status)
        error.http_status
      elsif error.respond_to?(:status_code)
        error.status_code
      elsif error.respond_to?(:response) && error.response.respond_to?(:code)
        error.response.code.to_i
      elsif error.message =~ /(\d{3})/
        # Extract 3-digit HTTP status code from error message
        $1.to_i
      else
        nil
      end
    end
end
