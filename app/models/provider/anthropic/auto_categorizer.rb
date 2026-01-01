class Provider::Anthropic::AutoCategorizer
  def initialize(client, transactions: [], user_categories: [])
    @client = client
    @transactions = transactions
    @user_categories = user_categories
  end

  def auto_categorize
    response = client.messages(
      parameters: {
        model: "claude-3-5-sonnet-20241022",
        system: system_prompt,
        messages: [
          { role: "user", content: prompt },
          { role: "assistant", content: "{" }
        ],
        max_tokens: 4096
      }
    )

    text = "{" + response.dig("content", 0, "text")

    build_response(extract_categorizations(text))
  rescue => e
    Rails.logger.error("Anthropic Auto-categorization error: #{e.message}")
    raise Provider::Anthropic::Error, "Anthropic error: #{e.message}"
  end

  private
    attr_reader :client, :transactions, :user_categories

    AutoCategorization = Provider::LlmConcept::AutoCategorization

    def build_response(categorizations)
      categorizations.map do |categorization|
        AutoCategorization.new(
          transaction_id: categorization.dig("transaction_id"),
          category_name: normalize_category_name(categorization.dig("category_name")),
        )
      end
    end

    def normalize_category_name(category_name)
      return nil if category_name == "null"
      category_name
    end

    def extract_categorizations(text)
      response_json = JSON.parse(text)
      response_json.dig("categorizations")
    end

    def system_prompt
      "You are a helpful assistant that categorizes financial transactions. You must output valid JSON only."
    end

    def prompt
      <<~PROMPT
        You are an assistant to a consumer personal finance app.#{' '}
        You will be provided a list of the user's transactions and a list of the user's categories.
        Your job is to auto-categorize each transaction.

        Here are the user's available categories:
        #{user_categories.to_json}

        Here are the transactions to categorize:
        #{transactions.to_json}

        Closely follow ALL the rules below while auto-categorizing:
        - Return 1 result per transaction
        - Correlate each transaction by ID (transaction_id)
        - Attempt to match the most specific category possible (i.e. subcategory over parent category)
        - Category and transaction classifications should match (i.e. if transaction is an "expense", the category must have classification of "expense")
        - If you don't know the category, return "null"
          - You should always favor "null" over false positives
          - Be slightly pessimistic. Only match a category if you're 60%+ confident it is the correct one.
        - Each transaction has varying metadata that can be used to determine the category
          - Note: "hint" comes from 3rd party aggregators and typically represents a category name that may or may not match any of the user-supplied categories

        Output JSON matching this schema:
        {
          "categorizations": [
            { "transaction_id": "string", "category_name": "string or null" }
          ]
        }
      PROMPT
    end
end
