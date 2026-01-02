# app/services/account_type_detector.rb
class AccountTypeDetector
  PATTERNS = {
    "Investment" => {
      keywords: [ "401k", "403b", "ira", "roth", "brokerage", "investment", "trading", "stocks" ],
      institutions: [ "vanguard", "fidelity", "schwab", "etrade", "robinhood" ],
      default_subtype: nil
    },
    "CreditCard" => {
      keywords: [ "credit", "visa", "mastercard", "amex", "discover" ],
      institutions: [],
      default_subtype: nil
    },
    "Depository" => {
      keywords: [ "checking", "savings", "hsa", "money market", "cd" ],
      institutions: [],
      default_subtype: "checking"
    },
    "Loan" => {
      keywords: [ "mortgage", "loan", "auto loan", "student loan", "heloc" ],
      institutions: [],
      default_subtype: nil
    },
    "Crypto" => {
      keywords: [ "crypto", "bitcoin", "ethereum", "coinbase", "blockchain" ],
      institutions: [ "coinbase", "binance", "kraken" ],
      default_subtype: nil
    }
  }

  def initialize(account_name:, institution_name:)
    @account_name = (account_name || "").downcase
    @institution_name = (institution_name || "").downcase
  end

  def detect
    # Check institution patterns first (more reliable)
    PATTERNS.each do |type, config|
      if config[:institutions].any? { |inst| @institution_name.include?(inst) }
        return { accountable_type: type, subtype: config[:default_subtype] }
      end
    end

    # Check keyword patterns in account name
    PATTERNS.each do |type, config|
      if config[:keywords].any? { |keyword| @account_name.include?(keyword) }
        # For Depository, try to detect specific subtype
        subtype = detect_depository_subtype if type == "Depository"
        return { accountable_type: type, subtype: subtype || config[:default_subtype] }
      end
    end

    # Default fallback
    { accountable_type: "Depository", subtype: "checking" }
  end

  private

    def detect_depository_subtype
      return "savings" if @account_name.include?("savings")
      return "checking" if @account_name.include?("checking")
      return "hsa" if @account_name.include?("hsa")
      return "cd" if @account_name.include?("cd") || @account_name.include?("certificate")
      return "money_market" if @account_name.include?("money market")
      nil
    end
end
