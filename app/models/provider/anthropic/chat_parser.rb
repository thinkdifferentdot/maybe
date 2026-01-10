class Provider::Anthropic::ChatParser
  Error = Class.new(StandardError)

  def initialize(object)
    @object = object
  end

  # Parses Anthropic Messages API response into ChatResponse
  #
  # Multi-turn conversation flow:
  # 1. User calls chat_response with prompt
  # 2. If Claude requests tools, response.function_requests contains tool_use blocks
  # 3. Caller executes tools and creates function_results via ToolCall::Function.to_result
  # 4. Caller passes function_results to next chat_response call
  # 5. ChatConfig reconstructs conversation history (user -> assistant with tool_use -> user with tool_result)
  #
  # Note: Caller must manage conversation history (Anthropic lacks OpenAI's previous_response_id)
  def parsed
    ChatResponse.new(
      id: response_id,
      model: response_model,
      messages: messages,
      function_requests: function_requests
    )
  end

  private

  attr_reader :object

  ChatResponse = Provider::LlmConcept::ChatResponse
  ChatMessage = Provider::LlmConcept::ChatMessage
  ChatFunctionRequest = Provider::LlmConcept::ChatFunctionRequest

  def response_id
    object.dig(:id)
  end

  def response_model
    object.dig(:model)
  end

  # Anthropic Messages API returns content as an array of blocks
  # Extract text blocks for regular messages
  def messages
    # content is an array of blocks with type and text fields
    # Note: to_h returns hash with symbol keys (Anthropic gem symbolizes JSON)
    text_blocks = object.dig(:content)&.select { |block| block[:type] == :text } || []

    output_text = text_blocks.map { |block| block[:text] }.join("\n")

    # Return single ChatMessage with combined text
    [ChatMessage.new(
      id: response_id,
      output_text: output_text
    )]
  end

  # Extract tool_use blocks from Anthropic response
  # Anthropic returns tool_use blocks in the content array with type="tool_use"
  # Each tool_use block has: {type: "tool_use", id:, name:, input:}
  # Unlike OpenAI, Anthropic may call multiple tools in one response (parallel tool use)
  def function_requests
    tool_use_blocks = object.dig(:content)&.select { |block| block[:type] == :tool_use } || []

    tool_use_blocks.map do |block|
      ChatFunctionRequest.new(
        id: block[:id],
        call_id: block[:id], # Anthropic uses same id for both (unlike OpenAI's separate id/call_id)
        function_name: block[:name],
        function_args: block[:input] # Already a Hash (not JSON string like OpenAI)
      )
    end
  end
end
