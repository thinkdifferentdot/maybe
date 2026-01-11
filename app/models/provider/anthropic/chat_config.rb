class Provider::Anthropic::ChatConfig
  def initialize(functions: [], function_results: [])
    @functions = functions
    @function_results = function_results
  end

  # Builds messages array in Anthropic Messages API format
  # For basic text-only chat, returns a simple user message
  # For multi-turn with function_results, builds full conversation history
  def build_input(prompt)
    if function_results.empty?
      # Simple chat (no function_results)
      [ { role: "user", content: prompt } ]
    else
      # Multi-turn conversation with tool results
      # Anthropic requires:
      # 1. Original user message
      # 2. Assistant message with tool_use blocks
      # 3. User message with tool_result blocks (MUST come FIRST in content array)

      messages = [ { role: "user", content: prompt } ]

      # Reconstruct assistant message with tool_use blocks
      # The function_results include call_id which references the tool_use block id
      assistant_blocks = function_results.map do |fr|
        {
          type: "tool_use",
          id: fr[:call_id],
          name: fr[:name],
          input: fr[:arguments]
        }
      end
      messages << { role: "assistant", content: assistant_blocks }

      # Build tool_result blocks (CRITICAL: these MUST come FIRST)
      tool_result_blocks = function_results.map do |fr|
        output = fr[:output]
        content = if output.nil?
          ""
        elsif output.is_a?(String)
          output
        else
          output.to_json
        end

        {
          type: "tool_result",
          tool_use_id: fr[:call_id],
          content: content
        }
      end

      # User message with tool_result blocks FIRST
      # Additional text content could be added after tool_result blocks if needed
      messages << { role: "user", content: tool_result_blocks }

      messages
    end
  end

  # Converts Sure's functions format to Anthropic's tools format
  # Anthropic uses: {name, description, input_schema}
  # Unlike OpenAI which uses: {type: "function", function: {name, description, parameters, strict}}
  def tools
    functions.map do |fn|
      {
        name: fn[:name],
        description: fn[:description],
        input_schema: fn[:params_schema]
        # Note: Anthropic doesn't use "strict" parameter (ignore fn[:strict])
      }
    end
  end

  private

    attr_reader :functions, :function_results
end
