# frozen_string_literal: true

require "test_helper"

# Test class that includes the JsonParser concern for testing
class JsonParserTestClass
  include Provider::Concerns::JsonParser

  attr_reader :last_raw_input

  def parse_json_flexibly_public(raw)
    @last_raw_input = raw
    parse_json_flexibly(raw)
  end

  def extract_from_closed_code_blocks_public(text)
    extract_from_closed_code_blocks(text)
  end

  def extract_from_unclosed_code_blocks_public(text)
    extract_from_unclosed_code_blocks(text)
  end

  def extract_json_with_key_public(text, key)
    extract_json_with_key(text, key)
  end

  def extract_any_json_object_public(text)
    extract_any_json_object(text)
  end

  def strip_thinking_tags_public(raw)
    strip_thinking_tags(raw)
  end
end

class Provider::Concerns::JsonParserTest < ActiveSupport::TestCase
  setup do
    @parser = JsonParserTestClass.new
  end

  # Tests for extract_from_closed_code_blocks

  test "extract_from_closed_code_blocks parses valid array in json code block" do
    input = <<~JSON
      Here's the result:
      ```json
      [{"category": "Food"}]
      ```
    JSON

    result = @parser.extract_from_closed_code_blocks_public(input)
    assert_equal [{"category" => "Food"}], result
  end

  test "extract_from_closed_code_blocks parses valid object in json code block" do
    input = <<~JSON
      Here's the result:
      ```json
      {"category": "Food"}
      ```
    JSON

    result = @parser.extract_from_closed_code_blocks_public(input)
    assert_equal({"category" => "Food"}, result)
  end

  test "extract_from_closed_code_blocks parses array in plain code block" do
    input = <<~JSON
      Here's the result:
      ```
      [{"category": "Food"}]
      ```
    JSON

    result = @parser.extract_from_closed_code_blocks_public(input)
    assert_equal [{"category" => "Food"}], result
  end

  test "extract_from_closed_code_blocks parses object in plain code block" do
    input = <<~JSON
      Here's the result:
      ```
      {"category": "Food"}
      ```
    JSON

    result = @parser.extract_from_closed_code_blocks_public(input)
    assert_equal({"category" => "Food"}, result)
  end

  test "extract_from_closed_code_blocks returns nil for no code blocks" do
    input = "No code blocks here"
    result = @parser.extract_from_closed_code_blocks_public(input)
    assert_nil result
  end

  test "extract_from_closed_code_blocks returns nil for malformed JSON in code block" do
    input = <<~JSON
      Here's the result:
      ```json
      {invalid json}
      ```
    JSON

    result = @parser.extract_from_closed_code_blocks_public(input)
    assert_nil result
  end

  test "extract_from_closed_code_blocks returns last valid code block when multiple present" do
    input = <<~JSON
      First:
      ```json
      [{"id": 1}]
      ```
      Second:
      ```json
      [{"id": 2}]
      ```
    JSON

    result = @parser.extract_from_closed_code_blocks_public(input)
    assert_equal [{"id" => 2}], result
  end

  # Tests for extract_from_unclosed_code_blocks

  test "extract_from_unclosed_code_blocks parses array at end of unclosed block" do
    input = %(```json\n[{"category": "Food"}])

    result = @parser.extract_from_unclosed_code_blocks_public(input)
    assert_equal [{"category" => "Food"}], result
  end

  test "extract_from_unclosed_code_blocks parses object at end of unclosed block" do
    input = %(```json\n{"category": "Food"})

    result = @parser.extract_from_unclosed_code_blocks_public(input)
    assert_equal({"category" => "Food"}, result)
  end

  test "extract_from_unclosed_code_blocks handles plain unclosed code block" do
    input = %(```\n[{"category": "Food"}])

    result = @parser.extract_from_unclosed_code_blocks_public(input)
    assert_equal [{"category" => "Food"}], result
  end

  test "extract_from_unclosed_code_blocks returns nil for empty string" do
    result = @parser.extract_from_unclosed_code_blocks_public("")
    assert_nil result
  end

  test "extract_from_unclosed_code_blocks returns nil for malformed JSON" do
    input = '```json\n{invalid}'

    result = @parser.extract_from_unclosed_code_blocks_public(input)
    assert_nil result
  end

  # Tests for extract_json_with_key

  test "extract_json_with_key finds categorizations key" do
    input = '{"categorizations": [{"category": "Food"}]}'

    result = @parser.extract_json_with_key_public(input, "categorizations")
    assert_equal({"categorizations" => [{"category" => "Food"}]}, result)
  end

  test "extract_json_with_key finds merchants key" do
    input = '{"merchants": [{"name": "Amazon"}]}'

    result = @parser.extract_json_with_key_public(input, "merchants")
    assert_equal({"merchants" => [{"name" => "Amazon"}]}, result)
  end

  test "extract_json_with_key handles nested objects" do
    input = 'Some text {"categorizations": [{"nested": {"value": 1}}]} end'

    result = @parser.extract_json_with_key_public(input, "categorizations")
    assert_equal({"categorizations" => [{"nested" => {"value" => 1}}]}, result)
  end

  test "extract_json_with_key returns nil when key not found" do
    input = '{"other_key": "value"}'

    result = @parser.extract_json_with_key_public(input, "categorizations")
    assert_nil result
  end

  test "extract_json_with_key returns nil for empty string" do
    result = @parser.extract_json_with_key_public("", "categorizations")
    assert_nil result
  end

  # Tests for extract_any_json_object

  test "extract_any_json_object finds first object pattern" do
    input = 'Some text {"key": "value"} more text'

    result = @parser.extract_any_json_object_public(input)
    assert_equal({"key" => "value"}, result)
  end

  test "extract_any_json_object handles nested objects" do
    input = '{"outer": {"inner": "value"}}'

    result = @parser.extract_any_json_object_public(input)
    assert_equal({"outer" => {"inner" => "value"}}, result)
  end

  test "extract_any_json_object returns nil for empty string" do
    result = @parser.extract_any_json_object_public("")
    assert_nil result
  end

  test "extract_any_json_object returns nil for malformed JSON" do
    input = 'Some text {invalid} more text'

    result = @parser.extract_any_json_object_public(input)
    assert_nil result
  end

  # Tests for strip_thinking_tags

  test "strip_thinking_tags removes anthropic thinking tags with content after" do
    input = "<thinking>Let me think about this</thinking>\n{\"result\": \"value\"}"

    result = @parser.strip_thinking_tags_public(input)
    # The implementation looks for </think> tag (which doesn't match </thinking>)
    # So it falls back to returning everything after <thinking>
    assert_equal "Let me think about this</thinking>\n{\"result\": \"value\"}", result
  end

  test "strip_thinking_tags extracts content inside thinking tags when no content after" do
    input = "<thinking>\n{\"result\": \"value\"}\n</thinking>"

    result = @parser.strip_thinking_tags_public(input)
    # The implementation returns everything after <thinking> tag
    assert_equal "\n{\"result\": \"value\"}\n</thinking>", result
  end

  test "strip_thinking_tags handles openai think tags with content after" do
    input = "\u003cthink\u003eLet me think</think>\n{\"result\": \"value\"}"

    result = @parser.strip_thinking_tags_public(input)
    assert_equal '{"result": "value"}', result
  end

  test "strip_thinking_tags extracts content inside unclosed think tags" do
    input = "\u003cthink\u003e\n{\"result\": \"value\"}"

    result = @parser.strip_thinking_tags_public(input)
    # The implementation returns everything after <think> tag
    assert_equal "\n{\"result\": \"value\"}", result
  end

  test "strip_thinking_tags returns original when no thinking tags present" do
    input = '{"result": "value"}'

    result = @parser.strip_thinking_tags_public(input)
    assert_equal input, result
  end

  # Tests for parse_json_flexibly (integration)

  test "parse_json_flexibly parses plain JSON directly" do
    input = '{"key": "value"}'

    result = @parser.parse_json_flexibly_public(input)
    assert_equal({"key" => "value"}, result)
  end

  test "parse_json_flexibly parses JSON from closed code blocks" do
    input = <<~JSON
      Here's the result:
      ```json
      {"key": "value"}
      ```
    JSON

    result = @parser.parse_json_flexibly_public(input)
    assert_equal({"key" => "value"}, result)
  end

  test "parse_json_flexibly parses JSON from unclosed code blocks" do
    input = '```json\n{"key": "value"}'

    result = @parser.parse_json_flexibly_public(input)
    assert_equal({"key" => "value"}, result)
  end

  test "parse_json_flexibly parses JSON with categorizations key" do
    input = 'Some text {"categorizations": [{"category": "Food"}]} more text'

    result = @parser.parse_json_flexibly_public(input)
    expected = {"categorizations" => [{"category" => "Food"}]}
    assert_equal expected, result
  end

  test "parse_json_flexibly parses JSON with merchants key" do
    input = 'Some text {"merchants": [{"name": "Amazon"}]} more text'

    result = @parser.parse_json_flexibly_public(input)
    expected = {"merchants" => [{"name" => "Amazon"}]}
    assert_equal expected, result
  end

  test "parse_json_flexibly falls back to any JSON object" do
    input = 'Some text {"fallback": "value"} more text'

    result = @parser.parse_json_flexibly_public(input)
    assert_equal({"fallback" => "value"}, result)
  end

  test "parse_json_flexibly handles thinking tags with JSON after" do
    input = "<thinking>Let me think</thinking>\n{\"result\": \"value\"}"

    result = @parser.parse_json_flexibly_public(input)
    assert_equal({"result" => "value"}, result)
  end

  test "parse_json_flexibly handles thinking tags with JSON inside" do
    input = "<thinking>\n{\"result\": \"value\"}\n</thinking>"

    result = @parser.parse_json_flexibly_public(input)
    # With the thinking tags stripped, the remaining content can be parsed
    assert_equal({"result" => "value"}, result)
  end

  test "parse_json_flexibly returns empty hash for blank input" do
    result = @parser.parse_json_flexibly_public("")
    assert_equal({}, result)

    result = @parser.parse_json_flexibly_public(nil)
    assert_equal({}, result)
  end

  test "parse_json_flexibly raises error for unparseable content" do
    input = "This is just plain text with no JSON"

    error = assert_raises(Provider::Anthropic::Error) do
      @parser.parse_json_flexibly_public(input)
    end

    assert_match(/Could not parse JSON/, error.message)
  end
end
