require "test_helper"

class Transactions::ConfidenceBadgeViewTest < ActionView::TestCase
  setup do
    @account = accounts(:depository)
  end

  test "renders check-circle icon for high confidence (>= 80%)" do
    transaction = Transaction.create!(extra: { "ai_categorization_confidence" => 0.85 })
    @account.entries.create!(
      entryable: transaction,
      name: "Test",
      amount: -10,
      currency: "USD",
      date: Date.current
    )

    html = render(partial: "transactions/confidence_badge", locals: { transaction: transaction })

    assert_includes html, "text-success", "High confidence badge should have success color"
    assert_includes html, "AI confidence score", "Badge should have title attribute"
    assert_includes html, "M22 11.08V12a10 10 0 1 1-5.93-9.14", "High confidence badge should have check-circle icon path"
  end

  test "renders minus-circle icon for medium confidence (60-80%)" do
    transaction = Transaction.create!(extra: { "ai_categorization_confidence" => 0.70 })
    @account.entries.create!(
      entryable: transaction,
      name: "Test",
      amount: -10,
      currency: "USD",
      date: Date.current
    )

    html = render(partial: "transactions/confidence_badge", locals: { transaction: transaction })

    assert_includes html, "text-warning", "Medium confidence badge should have warning color"
    assert_includes html, "circle cx=\"12\" cy=\"12\" r=\"10\"", "Medium confidence badge should have circle"
    assert_includes html, "M8 12h8", "Medium confidence badge should have minus path"
  end

  test "renders x-circle icon for low confidence (< 60%)" do
    transaction = Transaction.create!(extra: { "ai_categorization_confidence" => 0.50 })
    @account.entries.create!(
      entryable: transaction,
      name: "Test",
      amount: -10,
      currency: "USD",
      date: Date.current
    )

    html = render(partial: "transactions/confidence_badge", locals: { transaction: transaction })

    assert_includes html, "text-destructive", "Low confidence badge should have destructive color"
    assert_includes html, "circle cx=\"12\" cy=\"12\" r=\"10\"", "Low confidence badge should have circle"
    assert_includes html, "m15 9-6 6", "Low confidence badge should have x path"
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

  test "renders w-3 h-3 sizing classes for xs icon" do
    transaction = Transaction.create!(extra: { "ai_categorization_confidence" => 0.75 })
    @account.entries.create!(
      entryable: transaction,
      name: "Test",
      amount: -10,
      currency: "USD",
      date: Date.current
    )

    html = render(partial: "transactions/confidence_badge", locals: { transaction: transaction })

    assert_includes html, "w-3 h-3", "Badge should have w-3 h-3 sizing classes for xs icon"
  end

  test "boundary: 80% renders check-circle icon with success color" do
    transaction = Transaction.create!(extra: { "ai_categorization_confidence" => 0.80 })
    @account.entries.create!(
      entryable: transaction,
      name: "Test",
      amount: -10,
      currency: "USD",
      date: Date.current
    )

    html = render(partial: "transactions/confidence_badge", locals: { transaction: transaction })

    assert_includes html, "text-success", "Confidence of exactly 80% should render success color"
    assert_includes html, "M22 11.08V12a10 10 0 1 1-5.93-9.14", "Confidence of exactly 80% should render check-circle icon path"
  end

  test "boundary: 60% renders minus-circle icon with warning color" do
    transaction = Transaction.create!(extra: { "ai_categorization_confidence" => 0.60 })
    @account.entries.create!(
      entryable: transaction,
      name: "Test",
      amount: -10,
      currency: "USD",
      date: Date.current
    )

    html = render(partial: "transactions/confidence_badge", locals: { transaction: transaction })

    assert_includes html, "text-warning", "Confidence of exactly 60% should render warning color"
    assert_includes html, "M8 12h8", "Confidence of exactly 60% should render minus path"
  end

  test "boundary: 59% renders x-circle icon with destructive color" do
    transaction = Transaction.create!(extra: { "ai_categorization_confidence" => 0.59 })
    @account.entries.create!(
      entryable: transaction,
      name: "Test",
      amount: -10,
      currency: "USD",
      date: Date.current
    )

    html = render(partial: "transactions/confidence_badge", locals: { transaction: transaction })

    assert_includes html, "text-destructive", "Confidence of 59% should render destructive color"
    assert_includes html, "m15 9-6 6", "Confidence of 59% should render x path"
  end
end
