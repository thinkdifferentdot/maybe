# frozen_string_literal: true

# Shared error handling concern for all LLM providers
# Handles provider-specific error types and translates them to standardized errors
# Logs all errors to Langfuse spans with level: "ERROR"
module Provider::Concerns::ErrorHandler
  extend ActiveSupport::Concern

  private

    # Wraps a block with Anthropic-specific error handling
    # Catches all Anthropic SDK errors and translates them to Provider::Anthropic::Error
    # Logs errors to Langfuse span with level: "ERROR"
    def with_anthropic_error_handler(span:, operation:)
      yield
    rescue Anthropic::Errors::APIConnectionError => e
      handle_anthropic_connection_error(e, span:, operation:)
    rescue Anthropic::Errors::APITimeoutError => e
      handle_anthropic_timeout_error(e, span:, operation:)
    rescue Anthropic::Errors::RateLimitError => e
      handle_anthropic_rate_limit_error(e, span:, operation:)
    rescue Anthropic::Errors::AuthenticationError => e
      handle_anthropic_authentication_error(e, span:, operation:)
    rescue Anthropic::Errors::APIStatusError => e
      handle_anthropic_status_error(e, span:, operation:)
    rescue JSON::ParserError => e
      handle_anthropic_json_error(e, span:, operation:)
    rescue => e
      handle_anthropic_generic_error(e, span:, operation:)
    end

    # Wraps a block with OpenAI-specific error handling
    # Catches common OpenAI/Faraday errors and translates them to Provider::Openai::Error
    # Note: Faraday::BadRequestError is NOT handled here - it's used for JSON mode fallback logic
    def with_openai_error_handler(span:, operation:)
      yield
    rescue Faraday::ConnectionFailed => e
      handle_openai_connection_error(e, span:, operation:)
    rescue JSON::ParserError => e
      handle_openai_json_error(e, span:, operation:)
    rescue => e
      handle_openai_generic_error(e, span:, operation:)
    end

    # Anthropic error handlers

    def handle_anthropic_connection_error(error, span:, operation:)
      log_error_to_span(span, error.message)
      raise Provider::Anthropic::Error, "Failed to connect to Anthropic API: #{error.message}"
    end

    def handle_anthropic_timeout_error(error, span:, operation:)
      log_error_to_span(span, error.message)
      raise Provider::Anthropic::Error, "Anthropic API request timed out: #{error.message}"
    end

    def handle_anthropic_rate_limit_error(error, span:, operation:)
      log_error_to_span(span, error.message)
      raise Provider::Anthropic::Error, "Anthropic API rate limit exceeded: #{error.message}"
    end

    def handle_anthropic_authentication_error(error, span:, operation:)
      log_error_to_span(span, error.message)
      raise Provider::Anthropic::Error, "Anthropic API authentication failed: #{error.message}"
    end

    def handle_anthropic_status_error(error, span:, operation:)
      log_error_to_span(span, error.message, status: error.status)
      raise Provider::Anthropic::Error, "Anthropic API error (#{error.status}): #{error.message}"
    end

    def handle_anthropic_json_error(error, span:, operation:)
      log_error_to_span(span, error.message)
      raise Provider::Anthropic::Error, "Invalid JSON response from Anthropic: #{error.message}"
    end

    def handle_anthropic_generic_error(error, span:, operation:)
      log_error_to_span(span, error.message)
      raise Provider::Anthropic::Error, "Unexpected error during #{operation}: #{error.message}"
    end

    # OpenAI error handlers

    def handle_openai_connection_error(error, span:, operation:)
      log_error_to_span(span, error.message)
      raise Provider::Openai::Error, "Failed to connect to OpenAI API: #{error.message}"
    end

    def handle_openai_json_error(error, span:, operation:)
      log_error_to_span(span, error.message)
      raise Provider::Openai::Error, "Invalid JSON response from OpenAI: #{error.message}"
    end

    def handle_openai_generic_error(error, span:, operation:)
      log_error_to_span(span, error.message)
      raise Provider::Openai::Error, "Unexpected error during #{operation}: #{error.message}"
    end

    # Shared helper

    def log_error_to_span(span, message, **extra_output)
      return unless span

      output = { error: message }
      output.merge!(extra_output) if extra_output.any?
      span.end(output: output, level: "ERROR")
    end
end
