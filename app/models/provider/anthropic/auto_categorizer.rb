class Provider::Anthropic::AutoCategorizer
  def initialize(client, transactions: [], user_categories: [], options: {})
    @client = client
    @transactions = transactions
    @user_categories = user_categories
    @options = options
  end

  def auto_categorize
    response = client.messages(
      parameters: {
        model: Setting.anthropic_categorization_model,
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
    attr_reader :client, :transactions, :user_categories, :options

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
      threshold = options[:confidence_threshold] || 60
      null_tolerance_text = null_tolerance_instruction(options[:null_tolerance] || "pessimistic")
      subcategory_text = subcategory_instruction(options[:prefer_subcategories])
      classification_text = classification_instruction(options[:enforce_classification])

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
        #{subcategory_text}
        #{classification_text}
        - If you don't know the category, return "null"
          #{null_tolerance_text}
          - Only match a category if you're #{threshold}%+ confident it is the correct one.
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

    def subcategory_instruction(prefer_subcategories)
      # default to true if nil
      prefer = prefer_subcategories.nil? ? true : prefer_subcategories

      if prefer
        "- Attempt to match the most specific category possible (i.e. subcategory over parent category)"
      else
        "- Match to parent categories when appropriate. Only use subcategories when you're confident about the specific use case."
      end
    end

    def classification_instruction(enforce)
      # default to true if nil
      should_enforce = enforce.nil? ? true : enforce

      if should_enforce
        "- Category and transaction classifications MUST match (i.e. if transaction is an \"expense\", the category must have classification of \"expense\")"
      else
        "- Category and transaction classifications should generally match, but use your best judgment."
      end
    end

    def null_tolerance_instruction(tolerance)
      case tolerance
      when "pessimistic"
        "- You should always favor \"null\" over false positives. Be slightly pessimistic."
      when "balanced"
        "- Favor accuracy over completeness. Return \"null\" when uncertain."
      when "optimistic"
        "- Attempt to match categories whenever plausible. Only return \"null\" when truly uncertain."
      else
        "- You should always favor \"null\" over false positives. Be slightly pessimistic."
      end
    end
end
