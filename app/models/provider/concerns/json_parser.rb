# frozen_string_literal: true

# Shared JSON parsing concern for all LLM providers
# Handles flexible JSON parsing from LLM responses with multiple fallback strategies
module Provider::Concerns::JsonParser
  extend ActiveSupport::Concern

  private

    # Flexible JSON parsing that handles common LLM output issues
    #
    # Tries multiple extraction strategies in order of preference:
    # 1. Direct JSON.parse on cleaned input
    # 2. Closed markdown code blocks (```json...```)
    # 3. Unclosed markdown code blocks (thinking models often forget to close)
    # 4. Find JSON object with specific key (e.g., "categorizations", "merchants")
    # 5. Find any JSON object (last resort)
    #
    # Raises Provider::Anthropic::Error if all strategies fail
    def parse_json_flexibly(raw)
      return {} if raw.blank?

      # Strip thinking model tags if present (e.g., <thinking>...</thinking>)
      # The actual JSON output comes after the thinking block
      cleaned = strip_thinking_tags(raw)

      # Try direct parse first
      JSON.parse(cleaned)
    rescue JSON::ParserError
      # Try multiple extraction strategies in order of preference

      # Strategy 1: Closed markdown code blocks (```json...```)
      # Handle both objects {...} and arrays [...]
      if (result = extract_from_closed_code_blocks(cleaned))
        return result
      end

      # Strategy 2: Unclosed markdown code blocks (thinking models often forget to close)
      if (result = extract_from_unclosed_code_blocks(cleaned))
        return result
      end

      # Strategy 3: Find JSON object with specific keys
      if (result = extract_json_with_key(cleaned, "categorizations"))
        return result
      end

      if (result = extract_json_with_key(cleaned, "merchants"))
        return result
      end

      # Strategy 4: Find any JSON object (last resort)
      if cleaned =~ /(\{[\s\S]*\})/m
        begin
          return JSON.parse($1)
        rescue JSON::ParserError
          # Fall through to error
        end
      end

      raise Provider::Anthropic::Error, "Could not parse JSON from response: #{raw.truncate(200)}"
    end

    # Strip thinking model tags from response
    # Handles both Anthropic (<thinking>...</thinking>) and OpenAI/o1 formats
    #
    # Some models like Qwen-thinking output reasoning in these tags before the actual response.
    # The method extracts content after the closing tag, or falls back to content inside the tag
    # if no closing tag is present.
    def strip_thinking_tags(raw)
      # Handle OpenAI/o1 format (special think tags)
      if raw.include?("\u003cthink\u003e")
        # Check if there's content after the thinking block
        if raw =~ /<\/think>\s*([\s\S]*)/m
          after_thinking = $1.strip
          return after_thinking if after_thinking.present?
        end
        # If no content after closing think tag or no closing tag, look inside the thinking block
        # The JSON might be the last thing in the thinking block
        if raw =~ /\u003cthink\u003e([\s\S]*)/m
          return $1
        end
      end

      # Handle Anthropic format: <thinking>...</thinking>
      if raw.include?("<thinking>")
        # Check if there's content after the thinking block
        if raw =~ /<\/think>\s*([\s\S]*)/m
          after_thinking = $1.strip
          return after_thinking if after_thinking.present?
        end
        # If no content after </thinking> or no closing tag, look inside the thinking block
        # The JSON might be the last thing in the thinking block
        if raw =~ /<thinking>([\s\S]*)/m
          return $1
        end
      end

      raw
    end

    # Extract JSON from closed markdown code blocks (```json...```)
    # Handles both array [...] and object {...} patterns
    # Returns parsed JSON or nil if no valid JSON found
    def extract_from_closed_code_blocks(text)
      # Try arrays first: ```json [...] ```
      if text =~ /```(?:json)?\s*(\[[\s\S]*?\])\s*```/m
        matches = text.scan(/```(?:json)?\s*(\[[\s\S]*?\])\s*```/m).flatten
        matches.reverse_each do |match|
          begin
            return JSON.parse(match)
          rescue JSON::ParserError
            next
          end
        end
      end

      # Try objects: ```json {...} ```
      if text =~ /```(?:json)?\s*(\{[\s\S]*?\})\s*```/m
        matches = text.scan(/```(?:json)?\s*(\{[\s\S]*?\})\s*```/m).flatten
        matches.reverse_each do |match|
          begin
            return JSON.parse(match)
          rescue JSON::ParserError
            next
          end
        end
      end

      nil
    end

    # Extract JSON from unclosed markdown code blocks
    # Thinking models often forget to close ```json or ``` blocks
    # Returns parsed JSON or nil if no valid JSON found
    def extract_from_unclosed_code_blocks(text)
      # Try arrays first: ```json [...
      if text =~ /```(?:json)?\s*(\[[\s\S]*\])\s*$/m
        begin
          return JSON.parse($1)
        rescue JSON::ParserError
          # Try objects next
        end
      end

      # Try objects: ```json {...
      if text =~ /```(?:json)?\s*(\{[\s\S]*\})\s*$/m
        begin
          return JSON.parse($1)
        rescue JSON::ParserError
          # Return nil for both failing
        end
      end

      nil
    end

    # Extract JSON object containing a specific key
    # Finds JSON objects like {"categorizations": [...]} or {"merchants": [...]}
    # Tries non-greedy match first, then greedy match as fallback
    # Returns parsed JSON or nil if no valid JSON found
    def extract_json_with_key(text, key)
      # Build regex pattern for the specific key
      pattern = /(\{\"\#{key}\"\s*:\s*\[[\s\S]*\]\s*\})/m

      if text =~ pattern
        # Try non-greedy matches first
        non_greedy_pattern = /(\{\"\#{key}\"\s*:\s*\[[\s\S]*?\]\s*\})/m
        matches = text.scan(non_greedy_pattern).flatten
        matches.reverse_each do |match|
          begin
            return JSON.parse(match)
          rescue JSON::ParserError
            next
          end
        end

        # Try greedy match as fallback
        begin
          return JSON.parse($1)
        rescue JSON::ParserError
          # Return nil for both failing
        end
      end

      nil
    end
end
