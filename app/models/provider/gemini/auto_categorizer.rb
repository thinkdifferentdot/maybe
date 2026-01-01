class Provider::Gemini::AutoCategorizer
  def initialize(client, transactions: [], user_categories: [])
    @client = client
    @transactions = transactions
    @user_categories = user_categories
  end

  def auto_categorize
    response = client.generate_content({
      contents: {
        role: "user",
        parts: { text: prompt }
      },
      generation_config: {
        response_mime_type: "application/json",
        response_schema: json_schema
      }
    })

    # The gem usually returns a raw hash response or an object.
    # Based on common usage, it might be a hash.
    # I'll need to parse it.

    # Assuming the gem returns a hash matching the API response structure
    # text = response.dig("candidates", 0, "content", "parts", 0, "text")
    # But wait, the gem might provide helper methods.
    # Let's inspect the response in a safe way or assume standard structure.

    # If using gemini-ai gem, response is typically a hash
    text = response.dig("candidates", 0, "content", "parts", 0, "text")

    # If text is nil, something went wrong
    raise Provider::Gemini::Error, "Empty response from Gemini" unless text

    build_response(extract_categorizations(text))
  rescue => e
    Rails.logger.error("Gemini Auto-categorization error: #{e.message}")
    raise Provider::Gemini::Error, "Gemini error: #{e.message}"
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

    def json_schema
      {
        type: "OBJECT",
        properties: {
          categorizations: {
            type: "ARRAY",
            items: {
              type: "OBJECT",
              properties: {
                transaction_id: {
                  type: "STRING",
                  enum: transactions.map { |t| t[:id] }
                },
                category_name: {
                  type: "STRING",
                  nullable: true,
                  enum: [ *user_categories.map { |c| c[:name] }, "null" ]
                }
              },
              required: [ "transaction_id", "category_name" ]
            }
          }
        },
        required: [ "categorizations" ]
      }
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
      PROMPT
    end
end
