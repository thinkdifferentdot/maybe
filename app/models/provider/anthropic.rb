class Provider::Anthropic < Provider
  include LlmConcept

  # Subclass so errors caught in this provider are raised as Provider::Anthropic::Error
  Error = Class.new(Provider::Error)

  # Supported Anthropic model prefixes (e.g., "claude-sonnet", "claude-opus", etc.)
  DEFAULT_ANTHROPIC_MODEL_PREFIXES = %w[claude-]
  DEFAULT_MODEL = "claude-sonnet-4-5-20250929"

  class << self
    # Returns the effective model that would be used by the provider
    # Uses the same logic as Provider::Registry and the initializer
    def effective_model
      configured_model = ENV.fetch("ANTHROPIC_MODEL", nil)
      configured_model.presence || DEFAULT_MODEL
    end
  end

  def initialize(access_token, model: nil)
    @client = ::Anthropic::Client.new(api_key: access_token)
    @default_model = model.presence || DEFAULT_MODEL
  end

  def provider_name
    "Anthropic"
  end

  def supports_model?(model)
    DEFAULT_ANTHROPIC_MODEL_PREFIXES.any? { |prefix| model.start_with?(prefix) }
  end

  def supported_models_description
    "models starting with: #{DEFAULT_ANTHROPIC_MODEL_PREFIXES.join(', ')}"
  end

  def auto_categorize(transactions: [], user_categories: [], model: "", family: nil)
    with_provider_response do
      raise Error, "Too many transactions to auto-categorize. Max is 25 per request." if transactions.size > 25
      if user_categories.blank?
        family_id = family&.id || "unknown"
        Rails.logger.error("Cannot auto-categorize transactions for family #{family_id}: no categories available")
        raise Error, "No categories available for auto-categorization"
      end

      effective_model = model.presence || @default_model

      trace = create_langfuse_trace(
        name: "anthropic.auto_categorize",
        input: { transactions: transactions, user_categories: user_categories }
      )

      result = AutoCategorizer.new(
        client,
        model: effective_model,
        transactions: transactions,
        user_categories: user_categories,
        langfuse_trace: trace,
        family: family
      ).auto_categorize

      trace&.update(output: result.map(&:to_h))

      result
    end
  end

  def auto_detect_merchants(transactions: [], user_merchants: [], model: "", family: nil)
    with_provider_response do
      raise Error, "Too many transactions to auto-detect merchants. Max is 25 per request." if transactions.size > 25

      effective_model = model.presence || @default_model

      trace = create_langfuse_trace(
        name: "anthropic.auto_detect_merchants",
        input: { transactions: transactions, user_merchants: user_merchants }
      )

      result = AutoMerchantDetector.new(
        client,
        model: effective_model,
        transactions: transactions,
        user_merchants: user_merchants,
        langfuse_trace: trace,
        family: family
      ).auto_detect_merchants

      trace&.update(output: result.map(&:to_h))

      result
    end
  end

  def chat_response(
    prompt,
    model:,
    instructions: nil,
    functions: [],
    function_results: [],
    streamer: nil,
    previous_response_id: nil,
    session_id: nil,
    user_identifier: nil,
    family: nil
  )
    with_provider_response do
      chat_config = ChatConfig.new(
        functions: functions,
        function_results: function_results
      )

      effective_model = model.presence || @default_model

      trace = create_langfuse_trace(
        name: "anthropic.chat_response",
        input: { prompt: prompt, model: effective_model, instructions: instructions },
        session_id: session_id,
        user_identifier: user_identifier
      )

      messages = chat_config.build_input(prompt)

      begin
        # Build parameters for Anthropic Messages API
        parameters = {
          model: effective_model,
          max_tokens: 4096, # Required by Anthropic API
          messages: messages
        }
        parameters[:system] = instructions if instructions.present?
        parameters[:tools] = chat_config.tools if chat_config.tools.present?

        # Use streaming if streamer proc is provided
        if streamer.present?
          streaming_chat_response(parameters:, effective_model:, streamer:, trace:, session_id:, user_identifier:, family:)
        else
          non_streaming_chat_response(parameters:, effective_model:, trace:, session_id:, user_identifier:, family:)
        end
      rescue => e
        log_langfuse_generation(
          name: "chat_response",
          model: effective_model,
          input: messages,
          error: e,
          session_id: session_id,
          user_identifier: user_identifier
        )

        record_llm_usage(family: family, model: effective_model, operation: "chat", error: e)

        raise
      end
    end
  end

  private

    attr_reader :client

    def streaming_chat_response(parameters:, effective_model:, streamer:, trace:, session_id:, user_identifier:, family:)
      collected_chunks = []

      # Create MessageStream and iterate events
      stream = client.messages.stream(parameters)

      # Create stream proxy proc that converts Anthropic events to ChatStreamChunk
      stream_proxy = proc do |event|
        parsed_chunk = ChatStreamParser.new(event, stream: stream).parsed

        unless parsed_chunk.nil?
          streamer.call(parsed_chunk)
          collected_chunks << parsed_chunk
        end
      end

      # Consume the stream
      stream.each(&stream_proxy)

      # Extract response and usage from collected chunks
      response_chunk = collected_chunks.find { |chunk| chunk.type == "response" }
      response = response_chunk.data
      usage = response_chunk.usage

      output_text = response.messages.map(&:output_text).join("\n")

      # Log Langfuse generation
      log_langfuse_generation(
        name: "chat_response",
        model: effective_model,
        input: parameters[:messages],
        output: output_text,
        usage: usage,
        session_id: session_id,
        user_identifier: user_identifier
      )

      record_llm_usage(family: family, model: effective_model, operation: "chat", usage: usage)

      response
    end

    def non_streaming_chat_response(parameters:, effective_model:, trace:, session_id:, user_identifier:, family:)
      raw_response = client.messages.create(parameters)

      # Convert Anthropic::Message (BaseModel) to hash for parsing
      response_hash = raw_response.to_h

      parsed = ChatParser.new(response_hash).parsed

      # Map Anthropic usage field names to LlmConcept format
      raw_usage = raw_response.usage
      usage = {
        "prompt_tokens" => raw_usage&.input_tokens,
        "completion_tokens" => raw_usage&.output_tokens,
        "total_tokens" => (raw_usage&.input_tokens || 0) + (raw_usage&.output_tokens || 0)
      }

      output_text = parsed.messages.map(&:output_text).join("\n")

      log_langfuse_generation(
        name: "chat_response",
        model: effective_model,
        input: parameters[:messages],
        output: output_text,
        usage: usage,
        session_id: session_id,
        user_identifier: user_identifier
      )

      record_llm_usage(family: family, model: effective_model, operation: "chat", usage: usage)

      parsed
    end

    def langfuse_client
      return unless ENV["LANGFUSE_PUBLIC_KEY"].present? && ENV["LANGFUSE_SECRET_KEY"].present?

      @langfuse_client = Langfuse.new
    end

    def create_langfuse_trace(name:, input:, session_id: nil, user_identifier: nil)
      return unless langfuse_client

      langfuse_client.trace(
        name: name,
        input: input,
        session_id: session_id,
        user_id: user_identifier,
        environment: Rails.env
      )
    rescue => e
      Rails.logger.warn("Langfuse trace creation failed: #{e.message}")
      nil
    end

    def log_langfuse_generation(name:, model:, input:, output: nil, usage: nil, error: nil, session_id: nil, user_identifier: nil)
      return unless langfuse_client

      trace = create_langfuse_trace(
        name: "anthropic.#{name}",
        input: input,
        session_id: session_id,
        user_identifier: user_identifier
      )

      generation = trace&.generation(
        name: name,
        model: model,
        input: input
      )

      if error
        generation&.end(
          output: { error: error.message },
          level: "ERROR"
        )
        trace&.update(
          output: { error: error.message },
          level: "ERROR"
        )
      else
        generation&.end(output: output, usage: usage)
        trace&.update(output: output)
      end
    rescue => e
      Rails.logger.warn("Langfuse logging failed: #{e.message}")
    end

    def record_llm_usage(family:, model:, operation:, usage: nil, error: nil)
      return unless family

      # For error cases, record with zero tokens
      if error.present?
        Rails.logger.info("Recording failed LLM usage - Error: #{error.message}")

        # Extract HTTP status code if available from the error
        http_status_code = extract_http_status_code(error)

        inferred_provider = LlmUsage.infer_provider(model)
        family.llm_usages.create!(
          provider: inferred_provider,
          model: model,
          operation: operation,
          prompt_tokens: 0,
          completion_tokens: 0,
          total_tokens: 0,
          estimated_cost: nil,
          metadata: {
            error: error.message,
            http_status_code: http_status_code
          }
        )

        Rails.logger.info("Failed LLM usage recorded successfully - Status: #{http_status_code}")
        return
      end

      return unless usage

      Rails.logger.info("Recording LLM usage - Raw usage data: #{usage.inspect}")

      prompt_tokens = usage["prompt_tokens"] || 0
      completion_tokens = usage["completion_tokens"] || 0
      total_tokens = usage["total_tokens"] || 0

      Rails.logger.info("Extracted tokens - prompt: #{prompt_tokens}, completion: #{completion_tokens}, total: #{total_tokens}")

      estimated_cost = LlmUsage.calculate_cost(
        model: model,
        prompt_tokens: prompt_tokens,
        completion_tokens: completion_tokens
      )

      # Log when we can't estimate the cost (e.g., custom/self-hosted models)
      if estimated_cost.nil?
        Rails.logger.info("Recording LLM usage without cost estimate for unknown model: #{model}")
      end

      inferred_provider = LlmUsage.infer_provider(model)
      family.llm_usages.create!(
        provider: inferred_provider,
        model: model,
        operation: operation,
        prompt_tokens: prompt_tokens,
        completion_tokens: completion_tokens,
        total_tokens: total_tokens,
        estimated_cost: estimated_cost,
        metadata: {}
      )

      Rails.logger.info("LLM usage recorded successfully - Cost: #{estimated_cost.inspect}")
    rescue => e
      Rails.logger.error("Failed to record LLM usage: #{e.message}")
    end

    def extract_http_status_code(error)
      # Try to extract HTTP status code from various error types
      # Anthropic gem errors may have status codes in different formats
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
