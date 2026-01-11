require "test_helper"

class Provider::Anthropic::ChatStreamParserTest < ActiveSupport::TestCase
  # Helper to create mock Anthropic stream events
  # The Anthropic SDK returns Struct objects with symbol types
  def mock_text_delta_event(text)
    OpenStruct.new(
      type: :content_block_delta,
      index: 0,
      delta: OpenStruct.new(type: :text_delta, text: text)
    )
  end

  def mock_message_delta_event(input_tokens, output_tokens)
    OpenStruct.new(
      type: :message_delta,
      delta: OpenStruct.new(stop_reason: :end_turn),
      usage: OpenStruct.new(input_tokens: input_tokens, output_tokens: output_tokens)
    )
  end

  def mock_message_stop_event
    OpenStruct.new(type: :message_stop)
  end

  def mock_content_block_start_event(id:, name:)
    OpenStruct.new(
      type: :content_block_start,
      index: 1,
      content_block: OpenStruct.new(type: :tool_use, id: id, name: name)
    )
  end

  def mock_tool_input_delta_event(partial_json)
    OpenStruct.new(
      type: :content_block_delta,
      index: 1,
      delta: OpenStruct.new(type: :input_json_delta, partial_json: partial_json)
    )
  end

  def mock_content_block_stop_event
    OpenStruct.new(type: :content_block_stop, index: 1)
  end

  def mock_ping_event
    OpenStruct.new(type: :ping)
  end

  def mock_message_start_event
    OpenStruct.new(type: :message_start, message: OpenStruct.new(id: "msg_123", model: "claude-sonnet-4-5"))
  end

  def mock_error_event(message)
    OpenStruct.new(type: :error, error: OpenStruct.new(message: message))
  end

  # Create a mock stream object for testing response building
  def mock_accumulated_message(id:, model:, content:, input_tokens:, output_tokens:)
    # Mock the __accumulated_message__ that the SDK provides
    usage = OpenStruct.new(
      input_tokens: input_tokens,
      output_tokens: output_tokens
    )
    message = OpenStruct.new(
      id: id,
      model: model,
      usage: usage,
      to_h: { id: id, model: model, content: content }
    )
    message
  end

  def mock_stream(accumulated_message: nil)
    stream = Object.new
    stream.define_singleton_method(:__accumulated_message__) do
      accumulated_message
    end
    stream
  end

  test "text delta event returns output_text chunk with delta text" do
    event = mock_text_delta_event("Hello")

    parser = Provider::Anthropic::ChatStreamParser.new(event)
    chunk = parser.parsed

    assert_not_nil chunk
    assert_equal "output_text", chunk.type
    assert_equal "Hello", chunk.data
    assert_nil chunk.usage
  end

  test "text delta events emit text chunks progressively" do
    stream = mock_stream

    # First chunk
    event1 = mock_text_delta_event("Hello, ")
    parser1 = Provider::Anthropic::ChatStreamParser.new(event1, stream: stream)
    chunk1 = parser1.parsed

    assert_equal "output_text", chunk1.type
    assert_equal "Hello, ", chunk1.data

    # Second chunk
    event2 = mock_text_delta_event("world!")
    parser2 = Provider::Anthropic::ChatStreamParser.new(event2, stream: stream)
    chunk2 = parser2.parsed

    assert_equal "output_text", chunk2.type
    assert_equal "world!", chunk2.data
  end

  test "message delta event returns nil" do
    event = mock_message_delta_event(10, 20)

    parser = Provider::Anthropic::ChatStreamParser.new(event)
    chunk = parser.parsed

    # message_delta doesn't emit a chunk
    assert_nil chunk
  end

  test "message stop event returns response chunk with usage from accumulated message" do
    accumulated_msg = mock_accumulated_message(
      id: "msg_123",
      model: "claude-sonnet-4-5",
      content: [{ type: :text, text: "Hello" }],
      input_tokens: 10,
      output_tokens: 5
    )
    stream = mock_stream(accumulated_message: accumulated_msg)

    event = mock_message_stop_event
    parser = Provider::Anthropic::ChatStreamParser.new(event, stream: stream)
    chunk = parser.parsed

    assert_not_nil chunk
    assert_equal "response", chunk.type
    assert_not_nil chunk.data
    assert_instance_of Provider::LlmConcept::ChatResponse, chunk.data
    assert_equal "msg_123", chunk.data.id
    assert_equal "claude-sonnet-4-5", chunk.data.model
    assert_equal 1, chunk.data.messages.size
    assert_equal "Hello", chunk.data.messages.first.output_text
    assert_not_nil chunk.usage
    assert_equal 10, chunk.usage["prompt_tokens"]
    assert_equal 5, chunk.usage["completion_tokens"]
    assert_equal 15, chunk.usage["total_tokens"]
  end

  test "unknown event type returns nil" do
    event = mock_ping_event

    parser = Provider::Anthropic::ChatStreamParser.new(event)
    chunk = parser.parsed

    assert_nil chunk
  end

  test "ping event returns nil" do
    event = mock_ping_event

    parser = Provider::Anthropic::ChatStreamParser.new(event)
    chunk = parser.parsed

    assert_nil chunk
  end

  test "message_start event returns nil" do
    event = mock_message_start_event

    parser = Provider::Anthropic::ChatStreamParser.new(event)
    chunk = parser.parsed

    assert_nil chunk
  end

  test "error event returns nil" do
    event = mock_error_event("Something went wrong")

    parser = Provider::Anthropic::ChatStreamParser.new(event)
    chunk = parser.parsed

    assert_nil chunk
  end

  test "tool use content_block_start returns nil" do
    event = mock_content_block_start_event(id: "tool_123", name: "get_weather")

    parser = Provider::Anthropic::ChatStreamParser.new(event)
    chunk = parser.parsed

    # content_block_start doesn't emit a chunk
    assert_nil chunk
  end

  test "tool use input delta returns nil" do
    stream = mock_stream

    delta_event = mock_tool_input_delta_event('{"city": "SF"}')
    parser = Provider::Anthropic::ChatStreamParser.new(delta_event, stream: stream)
    chunk = parser.parsed

    # Tool input delta doesn't emit a chunk
    assert_nil chunk
  end

  test "tool use content_block_stop returns nil" do
    event = mock_content_block_stop_event

    parser = Provider::Anthropic::ChatStreamParser.new(event)
    chunk = parser.parsed

    # content_block_stop doesn't emit a chunk
    assert_nil chunk
  end

  test "tool use is included in final response from accumulated message" do
    accumulated_msg = mock_accumulated_message(
      id: "msg_456",
      model: "claude-sonnet-4-5",
      content: [
        { type: :text, text: "I'll check the weather" },
        { type: :tool_use, id: "tool_123", name: "get_weather", input: { "city" => "SF" } }
      ],
      input_tokens: 20,
      output_tokens: 10
    )
    stream = mock_stream(accumulated_message: accumulated_msg)

    # Message stop should return response with tool use
    parser = Provider::Anthropic::ChatStreamParser.new(mock_message_stop_event, stream: stream)
    chunk = parser.parsed

    assert_equal "response", chunk.type
    assert_equal "msg_456", chunk.data.id
    assert_equal 1, chunk.data.function_requests.size
    assert_equal "get_weather", chunk.data.function_requests.first.function_name
    assert_equal({ "city" => "SF" }, chunk.data.function_requests.first.function_args)
  end

  test "response builds minimal response without accumulated message" do
    # Test fallback when stream doesn't have __accumulated_message__
    stream = mock_stream(accumulated_message: nil)

    # Message stop should build minimal response
    parser = Provider::Anthropic::ChatStreamParser.new(mock_message_stop_event, stream: stream)
    chunk = parser.parsed

    assert_equal "response", chunk.type
    assert_not_nil chunk.data.id
    # Without an accumulated message, we return an empty messages array
    assert_equal [], chunk.data.messages
    assert_equal 0, chunk.usage["prompt_tokens"]
    assert_equal 0, chunk.usage["completion_tokens"]
    assert_equal 0, chunk.usage["total_tokens"]
  end
end
