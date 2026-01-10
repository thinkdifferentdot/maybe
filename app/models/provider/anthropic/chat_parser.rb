class Provider::Anthropic::ChatParser
  Error = Class.new(StandardError)

  def initialize(object)
    @object = object
  end

  def parsed
    ChatResponse.new(
      id: response_id,
      model: response_model,
      messages: messages,
      function_requests: [] # No tool_use handling yet (plan 03-02)
    )
  end

  private

  attr_reader :object

  ChatResponse = Provider::LlmConcept::ChatResponse
  ChatMessage = Provider::LlmConcept::ChatMessage

  def response_id
    object.dig("id")
  end

  def response_model
    object.dig("model")
  end

  # Anthropic Messages API returns content as an array of blocks
  # For basic text-only responses, extract text blocks
  def messages
    # content is an array of blocks with type and text fields
    text_blocks = object.dig("content")&.select { |block| block["type"] == "text" } || []

    output_text = text_blocks.map { |block| block["text"] }.join("\n")

    # Return single ChatMessage with combined text
    [ChatMessage.new(
      id: response_id,
      output_text: output_text
    )]
  end
end
