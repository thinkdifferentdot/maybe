# test/services/account_type_detector_test.rb
require "test_helper"

class AccountTypeDetectorTest < ActiveSupport::TestCase
  test "detects Investment from 401k keyword" do
    detector = AccountTypeDetector.new(
      account_name: "Company 401k",
      institution_name: "Fidelity"
    )
    result = detector.detect
    assert_equal "Investment", result[:accountable_type]
  end

  test "detects Investment from institution name" do
    detector = AccountTypeDetector.new(
      account_name: "Brokerage Account",
      institution_name: "Vanguard"
    )
    result = detector.detect
    assert_equal "Investment", result[:accountable_type]
  end

  test "detects CreditCard from credit keyword" do
    detector = AccountTypeDetector.new(
      account_name: "Credit Card",
      institution_name: "Chase"
    )
    result = detector.detect
    assert_equal "CreditCard", result[:accountable_type]
  end

  test "detects Depository checking from checking keyword" do
    detector = AccountTypeDetector.new(
      account_name: "Checking Account",
      institution_name: "Wells Fargo"
    )
    result = detector.detect
    assert_equal "Depository", result[:accountable_type]
    assert_equal "checking", result[:subtype]
  end

  test "detects Depository savings from savings keyword" do
    detector = AccountTypeDetector.new(
      account_name: "Savings Account",
      institution_name: "Ally Bank"
    )
    result = detector.detect
    assert_equal "Depository", result[:accountable_type]
    assert_equal "savings", result[:subtype]
  end

  test "defaults to Depository checking when no patterns match" do
    detector = AccountTypeDetector.new(
      account_name: "Account 12345",
      institution_name: "Unknown Bank"
    )
    result = detector.detect
    assert_equal "Depository", result[:accountable_type]
    assert_equal "checking", result[:subtype]
  end

  test "detects Loan from mortgage keyword" do
    detector = AccountTypeDetector.new(
      account_name: "Home Mortgage",
      institution_name: "Quicken Loans"
    )
    result = detector.detect
    assert_equal "Loan", result[:accountable_type]
  end

  test "handles nil account name gracefully" do
    detector = AccountTypeDetector.new(
      account_name: nil,
      institution_name: "Chase"
    )
    result = detector.detect
    assert_equal "Depository", result[:accountable_type]
    assert_equal "checking", result[:subtype]
  end
end
