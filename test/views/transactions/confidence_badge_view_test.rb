require "test_helper"

class Transactions::ConfidenceBadgeViewTest < ActionView::TestCase
  setup do
    @account = accounts(:depository)
  end

  test "renders green text for high confidence (>= 80%)" do
    transaction = Transaction.create!(extra: { "ai_categorization_confidence" => 0.85 })
    @account.entries.create!(
      entryable: transaction,
      name: "Test",
      amount: -10,
      currency: "USD",
      date: Date.current
    )

    html = render(partial: "transactions/confidence_badge", locals: { transaction: transaction })

    assert_includes html, "text-green-600", "High confidence badge should have green text"
    assert_includes html, "font-medium", "Badge should have font-medium class"
    assert_includes html, "AI confidence score", "Badge should have title attribute"
  end

  test "renders yellow text for medium confidence (60-80%)" do
    transaction = Transaction.create!(extra: { "ai_categorization_confidence" => 0.70 })
    @account.entries.create!(
      entryable: transaction,
      name: "Test",
      amount: -10,
      currency: "USD",
      date: Date.current
    )

    html = render(partial: "transactions/confidence_badge", locals: { transaction: transaction })

    assert_includes html, "text-yellow-600", "Medium confidence badge should have yellow text"
    assert_includes html, "font-medium", "Badge should have font-medium class"
  end

  test "renders orange text for low confidence (< 60%)" do
    transaction = Transaction.create!(extra: { "ai_categorization_confidence" => 0.50 })
    @account.entries.create!(
      entryable: transaction,
      name: "Test",
      amount: -10,
      currency: "USD",
      date: Date.current
    )

    html = render(partial: "transactions/confidence_badge", locals: { transaction: transaction })

    assert_includes html, "text-orange-600", "Low confidence badge should have orange text"
    assert_includes html, "font-medium", "Badge should have font-medium class"
  end

  test "renders nothing when confidence is not present" do
    transaction = Transaction.create!
    @account.entries.create!(
      entryable: transaction,
      name: "Test",
      amount: -10,
      currency: "USD",
      date: Date.current
    )

    html = render(partial: "transactions/confidence_badge", locals: { transaction: transaction })

    assert_empty html.strip, "Badge should not render when confidence is not present"
  end

  test "renders nothing when extra is empty hash" do
    transaction = Transaction.create!(extra: {})
    @account.entries.create!(
      entryable: transaction,
      name: "Test",
      amount: -10,
      currency: "USD",
      date: Date.current
    )

    html = render(partial: "transactions/confidence_badge", locals: { transaction: transaction })

    assert_empty html.strip, "Badge should not render when extra is empty"
  end

  test "renders text-xs class for sizing" do
    transaction = Transaction.create!(extra: { "ai_categorization_confidence" => 0.75 })
    @account.entries.create!(
      entryable: transaction,
      name: "Test",
      amount: -10,
      currency: "USD",
      date: Date.current
    )

    html = render(partial: "transactions/confidence_badge", locals: { transaction: transaction })

    assert_includes html, "text-xs", "Badge should have text-xs sizing class"
  end

  test "boundary: 80% renders green" do
    transaction = Transaction.create!(extra: { "ai_categorization_confidence" => 0.80 })
    @account.entries.create!(
      entryable: transaction,
      name: "Test",
      amount: -10,
      currency: "USD",
      date: Date.current
    )

    html = render(partial: "transactions/confidence_badge", locals: { transaction: transaction })

    assert_includes html, "text-green-600", "Confidence of exactly 80% should render green"
  end

  test "boundary: 60% renders yellow" do
    transaction = Transaction.create!(extra: { "ai_categorization_confidence" => 0.60 })
    @account.entries.create!(
      entryable: transaction,
      name: "Test",
      amount: -10,
      currency: "USD",
      date: Date.current
    )

    html = render(partial: "transactions/confidence_badge", locals: { transaction: transaction })

    assert_includes html, "text-yellow-600", "Confidence of exactly 60% should render yellow"
  end

  test "boundary: 59% renders orange" do
    transaction = Transaction.create!(extra: { "ai_categorization_confidence" => 0.59 })
    @account.entries.create!(
      entryable: transaction,
      name: "Test",
      amount: -10,
      currency: "USD",
      date: Date.current
    )

    html = render(partial: "transactions/confidence_badge", locals: { transaction: transaction })

    assert_includes html, "text-orange-600", "Confidence of 59% should render orange"
  end
end
