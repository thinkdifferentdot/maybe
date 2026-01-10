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

  # Returns empty array for now - tools will be implemented in plan 03-02
  def tools
    []
  end

  private

  attr_reader :functions, :function_results
end
