class Provider::Anthropic::AutoMerchantDetector
  include Provider::Concerns::UsageRecorder
  include Provider::Concerns::JsonParser
  include Provider::Concerns::ErrorHandler

  attr_reader :client, :model, :transactions, :user_merchants, :langfuse_trace, :family

  def initialize(client, model:, transactions:, user_merchants:, langfuse_trace: nil, family: nil)
    @client = client
    @model = model
    @transactions = transactions
    @user_merchants = user_merchants
    @langfuse_trace = langfuse_trace
    @family = family
  end

  def auto_detect_merchants
    span = langfuse_trace&.span(name: "auto_detect_merchants_api_call", input: {
      model: model,
      transactions: transactions,
      user_merchants: user_merchants
    })

    with_anthropic_error_handler(span: span, operation: "merchant detection") do
      response = client.messages.create(
        model: model,
        max_tokens: 1024,
        messages: [ { role: "user", content: developer_message } ],
        system: instructions
      )

      # Note: response.usage is an Anthropic::Models::Usage BaseModel with input_tokens/output_tokens attributes
      usage_total = response.usage.input_tokens + response.usage.output_tokens
      Rails.logger.info("Tokens used to auto-detect merchants: #{usage_total}")

      merchants = extract_merchants(response)
      Rails.logger.debug("Extracted merchants: #{merchants.inspect}")
      result = build_response(merchants)

      record_usage(
        model,
        response.usage,
        operation: "auto_detect_merchants",
        metadata: {
          transaction_count: transactions.size,
          merchant_count: user_merchants.size
        }
      )

      span&.end(output: result.map(&:to_h), usage: {
        input_tokens: response.usage.input_tokens,
        output_tokens: response.usage.output_tokens,
        total_tokens: usage_total
      })

      result
    end
  end

  private

    AutoDetectedMerchant = Provider::LlmConcept::AutoDetectedMerchant

    def developer_message
      <<~MESSAGE.strip_heredoc
      Here are the user's available merchants in JSON format:

      ```json
      #{user_merchants.to_json}
      ```

      Use BOTH your knowledge AND the user-generated merchants to auto-detect the following transactions:

      ```json
      #{transactions.to_json}
      ```

      Return "null" if you are not 80%+ confident in your answer.
    MESSAGE
    end

    def instructions
      <<~INSTRUCTIONS.strip_heredoc
      You are an assistant to a consumer personal finance app.

      Closely follow ALL the rules below while auto-detecting business names and website URLs:

      - Return 1 result per transaction
      - Correlate each transaction by ID (transaction_id)
      - Do not include the subdomain in the business_url (i.e. "amazon.com" not "www.amazon.com")
      - User merchants are considered "manual" user-generated merchants and should only be used in 100% clear cases
      - Be slightly pessimistic.  We favor returning "null" over returning a false positive.
      - NEVER return a name or URL for generic transaction names (e.g. "Paycheck", "Laundromat", "Grocery store", "Local diner")

      Determining a value:

      - First attempt to determine the name + URL from your knowledge of global businesses
      - If no certain match, attempt to match one of the user-provided merchants
      - If no match, return "null"

      Example 1 (known business):

      ```
      Transaction name: "Some Amazon purchases"

      Result:
      - business_name: "Amazon"
      - business_url: "amazon.com"
      ```

      Example 2 (generic business):

      ```
      Transaction name: "local diner"

      Result:
      - business_name: null
      - business_url: null
      ```
    INSTRUCTIONS
    end

    def json_schema
      {
        type: "object",
        properties: {
          merchants: {
            type: "array",
            description: "An array of auto-detected merchant businesses for each transaction",
            items: {
              type: "object",
              properties: {
                transaction_id: {
                  type: "string",
                  description: "The internal ID of the original transaction",
                  enum: transactions.map { |t| t[:id] }
                },
                business_name: {
                  type: [ "string", "null" ],
                  description: "The detected business name of the transaction, or `null` if uncertain"
                },
                business_url: {
                  type: [ "string", "null" ],
                  description: "The URL of the detected business, or `null` if uncertain"
                }
              },
              required: [ "transaction_id", "business_name", "business_url" ],
              additionalProperties: false
            }
          }
        },
        required: [ "merchants" ],
        additionalProperties: false
      }
    end

    def build_response(merchants)
      merchants.map do |merchant|
        # Handle both string and symbol keys
        transaction_id = merchant["transaction_id"] || merchant[:transaction_id]
        business_name = merchant["business_name"] || merchant[:business_name]
        business_url = merchant["business_url"] || merchant[:business_url]

        AutoDetectedMerchant.new(
          transaction_id: transaction_id,
          business_name: normalize_merchant_value(business_name),
          business_url: normalize_merchant_value(business_url)
        )
      end
    end

    def normalize_merchant_value(value)
      return nil if value.nil? || value == "null" || value.to_s.downcase == "null"

      # Try to match against user merchants for name normalization
      if user_merchants.present?
        # Try exact match first
        exact_match = user_merchants.find { |m| m[:name] == value }
        return exact_match[:name] if exact_match

        # Try case-insensitive match
        case_match = user_merchants.find { |m| m[:name].to_s.downcase == value.to_s.downcase }
        return case_match[:name] if case_match
      end

      value
    end


    def extract_merchants(response)
      # Note: response.content contains BaseModel objects with symbolized type attributes
      content_block = response.content.find { |block| block.type == :text }
      raise Provider::Anthropic::Error, "No text content found in response" if content_block.nil?

      # Use flexible JSON parsing to handle various LLM output formats
      parsed = parse_json_flexibly(content_block.text)

      # Handle both { "merchants": [...] } and direct [...] formats
      if parsed.is_a?(Array)
        merchants = parsed
      else
        merchants = parsed.dig("merchants") || []
      end
      merchants
    rescue JSON::ParserError => e
      raise Provider::Anthropic::Error, "Invalid JSON in merchant detection response: #{e.message}"
    end
end
