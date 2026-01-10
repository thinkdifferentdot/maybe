class Provider::Anthropic::AutoMerchantDetector
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
    # Will be implemented in Task 2
  end

  private

  def developer_message
    # Will be implemented in Task 3
  end

  def instructions
    # Will be implemented in Task 3
  end

  def json_schema
    # Will be implemented in Task 3
  end

  def build_response(merchants)
    # Will be implemented in Task 2
  end

  def extract_merchants(response)
    # Will be implemented in Task 2
  end

  def record_usage(model_name, usage_data, operation:, metadata: {})
    # Will be implemented in Task 2
  end
end
