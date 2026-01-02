# app/services/account_type_change_validator.rb
class AccountTypeChangeValidator
  attr_reader :error_message

  def initialize(account, old_type, new_type)
    @account = account
    @old_type = old_type
    @new_type = new_type
    @error_message = nil
  end

  def valid?
    # Allow same type (e.g., just changing subtype)
    return true if @old_type == @new_type

    # Check for holdings
    if @account.holdings.exists? && !investment_type?(@new_type)
      @error_message = "Cannot change to #{display_name(@new_type)} because this account has investment holdings. Only Investment and Crypto accounts can have holdings."
      return false
    end

    # Check for trades
    if @account.trades.exists? && !investment_type?(@new_type)
      @error_message = "Cannot change to #{display_name(@new_type)} because this account has trades. Only Investment and Crypto accounts can have trades."
      return false
    end

    # All checks passed
    true
  end

  private

    def investment_type?(type)
      [ "Investment", "Crypto" ].include?(type)
    end

    def display_name(type)
      type.constantize.display_name
    end
end
