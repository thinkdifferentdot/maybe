class Provider::Anthropic::ChatStreamParser
  Error = Class.new(StandardError)

  def initialize(event, stream: nil)
    @event = event
    @stream = stream
  end

  # Parses Anthropic MessageStream events to ChatStreamChunk format
  #
  # Anthropic SDK returns Struct objects with symbol types:
  # - :content_block_delta with delta.type=:text_delta yields text chunks
  # - :message_delta contains usage metadata (input_tokens, output_tokens)
  # - :message_stop indicates stream completion
  # - :content_block_start/:content_block_stop for tool use tracking
  #
  # Returns ChatStreamChunk for handled events, nil for unhandled ones
  def parsed
    case event.type
    when :content_block_delta
      handle_content_block_delta
    when :message_delta
      handle_message_delta
    when :message_stop
      handle_message_stop
    when :content_block_start
      handle_content_block_start
    when :content_block_stop
      handle_content_block_stop
    when :ping, :error, :message_start
      # These event types don't produce chunks
      nil
    else
      Rails.logger.debug("Unhandled Anthropic stream event type: #{event.type}")
      nil
    end
  end

  private

    attr_reader :event, :stream

    Chunk = Provider::LlmConcept::ChatStreamChunk
    ChatResponse = Provider::LlmConcept::ChatResponse
    ChatMessage = Provider::LlmConcept::ChatMessage
    ChatFunctionRequest = Provider::LlmConcept::ChatFunctionRequest

    def handle_content_block_delta
      delta = event.delta

      case delta.type
      when :text_delta
        # Emit chunk for progressive rendering
        Chunk.new(type: "output_text", data: delta.text, usage: nil)
      when :input_json_delta
        # Tool input JSON - don't emit a chunk
        nil
      else
        Rails.logger.debug("Unhandled delta type: #{delta.type}")
        nil
      end
    end

    def handle_message_delta
      # message_delta doesn't produce a chunk, but we emit one for usage tracking
      # Include the usage in a format the caller can aggregate
      nil
    end

    def handle_message_stop
      # Build the complete response from the accumulated message
      response = build_response

      # Extract usage from the accumulated message
      usage = extract_usage_from_accumulated

      Chunk.new(type: "response", data: response, usage: usage)
    end

    def handle_content_block_start
      # Tool use block starts - no chunk emitted
      nil
    end

    def handle_content_block_stop
      # Tool use block stops - no chunk emitted
      nil
    end

    def build_response
      # Use the accumulated message from stream if available
      if stream && stream.respond_to?(:__accumulated_message__)
        accumulated_message = stream.__accumulated_message__
        if accumulated_message
          parse_accumulated_message(accumulated_message)
        else
          # Fallback: build a minimal response
          build_minimal_response
        end
      else
        # Fallback: build a minimal response
        build_minimal_response
      end
    end

    def build_minimal_response
      ChatResponse.new(
        id: SecureRandom.uuid,
        model: nil,
        messages: [],
        function_requests: []
      )
    end

    def extract_usage_from_accumulated
      # Try to extract usage from the accumulated message
      if stream && stream.respond_to?(:__accumulated_message__)
        accumulated_message = stream.__accumulated_message__
        if accumulated_message.respond_to?(:usage) && accumulated_message.usage
          raw_usage = accumulated_message.usage
          return {
            "prompt_tokens" => raw_usage.input_tokens,
            "completion_tokens" => raw_usage.output_tokens,
            "total_tokens" => (raw_usage.input_tokens || 0) + (raw_usage.output_tokens || 0)
          }
        end
      end

      # Fallback: return empty usage
      {
        "prompt_tokens" => 0,
        "completion_tokens" => 0,
        "total_tokens" => 0
      }
    end

    def parse_accumulated_message(message)
      # Convert the accumulated message (BaseModel) to hash
      message_hash = message.to_h

      ChatResponse.new(
        id: message_hash[:id] || SecureRandom.uuid,
        model: message_hash[:model],
        messages: build_messages(message_hash),
        function_requests: build_function_requests(message_hash)
      )
    end

    def build_messages(message_hash)
      # Extract text blocks from content
      text_blocks = message_hash[:content]&.select { |block| block[:type] == :text } || []
      output_text = text_blocks.map { |block| block[:text] }.join("\n")

      [
        ChatMessage.new(
          id: message_hash[:id] || SecureRandom.uuid,
          output_text: output_text
        )
      ]
    end

    def build_function_requests(message_hash)
      # Extract tool_use blocks from content
      tool_use_blocks = message_hash[:content]&.select { |block| block[:type] == :tool_use } || []

      tool_use_blocks.map do |block|
        # Convert hash keys with string/symbol handling
        block = block.transform_keys(&:to_sym)
        input = block[:input]
        # Ensure input is a hash (not a struct)
        input = input.to_h if input.respond_to?(:to_h)

        ChatFunctionRequest.new(
          id: block[:id],
          call_id: block[:id],
          function_name: block[:name],
          function_args: input
        )
      end
    end
end
