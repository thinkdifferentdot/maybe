class Provider::Openai < Provider
  include LlmConcept

  # Subclass so errors caught in this provider are raised as Provider::Openai::Error
  Error = Class.new(Provider::Error)

  MODELS = %w[gpt-4.1]

  FALLBACK_MODELS = [
    ["GPT-4o Mini (Recommended)", "gpt-4o-mini"],
    ["GPT-4o", "gpt-4o"],
    ["GPT-4 Turbo", "gpt-4-turbo"]
  ].freeze

  def self.list_available_models
    Rails.cache.fetch("openai_available_models", expires_in: 24.hours) do
      client = ::OpenAI::Client.new(access_token: Setting.openai_access_token)
      models = client.models.list["data"]

      # Filter to text-completion models suitable for categorization
      suitable_models = models.select { |m| m["id"].start_with?("gpt-") && !m["id"].include?("instruct") }

      suitable_models.map { |m| [m["id"], m["id"]] }.sort
    end
  rescue => e
    Rails.logger.error("Failed to fetch OpenAI models: #{e.message}")
    FALLBACK_MODELS
  end

  def initialize(access_token)
    @client = ::OpenAI::Client.new(access_token: access_token)
  end

  def supports_model?(model)
    MODELS.include?(model)
  end

  def auto_categorize(transactions: [], user_categories: [])
    with_provider_response do
      raise Error, "Too many transactions to auto-categorize. Max is 25 per request." if transactions.size > 25

      AutoCategorizer.new(
        client,
        transactions: transactions,
        user_categories: user_categories
      ).auto_categorize
    end
  end

  def auto_detect_merchants(transactions: [], user_merchants: [])
    with_provider_response do
      raise Error, "Too many transactions to auto-detect merchants. Max is 25 per request." if transactions.size > 25

      AutoMerchantDetector.new(
        client,
        transactions: transactions,
        user_merchants: user_merchants
      ).auto_detect_merchants
    end
  end

  def chat_response(prompt, model:, instructions: nil, functions: [], function_results: [], streamer: nil, previous_response_id: nil)
    with_provider_response do
      chat_config = ChatConfig.new(
        functions: functions,
        function_results: function_results
      )

      collected_chunks = []

      # Proxy that converts raw stream to "LLM Provider concept" stream
      stream_proxy = if streamer.present?
        proc do |chunk|
          parsed_chunk = ChatStreamParser.new(chunk).parsed

          unless parsed_chunk.nil?
            streamer.call(parsed_chunk)
            collected_chunks << parsed_chunk
          end
        end
      else
        nil
      end

      raw_response = client.responses.create(parameters: {
        model: model,
        input: chat_config.build_input(prompt),
        instructions: instructions,
        tools: chat_config.tools,
        previous_response_id: previous_response_id,
        stream: stream_proxy
      })

      # If streaming, Ruby OpenAI does not return anything, so to normalize this method's API, we search
      # for the "response chunk" in the stream and return it (it is already parsed)
      if stream_proxy.present?
        response_chunk = collected_chunks.find { |chunk| chunk.type == "response" }
        response_chunk.data
      else
        ChatParser.new(raw_response).parsed
      end
    end
  end

  private
    attr_reader :client
end
