class Provider::Anthropic::ChatConfig
  def initialize(functions: [], function_results: [])
    @functions = functions
    @function_results = function_results
  end

  # Builds messages array in Anthropic Messages API format
  # For basic text-only chat, returns a simple user message
  # Function results will be handled in plan 03-03
  def build_input(prompt)
    # Anthropic uses a messages array with role/content structure
    # For basic chat (no function_results), just return user message
    [{ role: "user", content: prompt }]
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
