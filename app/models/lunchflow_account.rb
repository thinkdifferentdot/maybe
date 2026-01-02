class LunchflowAccount < ApplicationRecord
  belongs_to :lunchflow_connection
  belongs_to :account, optional: true

  validates :lunchflow_id, presence: true, uniqueness: true
  validates :name, :institution_name, :provider, presence: true

  def ensure_account!
    return account if account.present?

    detected = AccountTypeDetector.new(
      account_name: name,
      institution_name: institution_name
    ).detect

    accountable = create_accountable_for_type(detected[:accountable_type])

    new_account = Account.create!(
      family: lunchflow_connection.family,
      name: "#{institution_name} - #{name}",
      currency: currency || lunchflow_connection.family.currency || "USD",
      balance: 0,
      accountable: accountable,
      subtype: detected[:subtype]
    )

    update!(account: new_account)
    new_account
  end

  private

    def create_accountable_for_type(type)
      type.constantize.create!
    end

    def potential_duplicates
      Account.where(family: lunchflow_connection.family)
             .where("name ILIKE ? OR name ILIKE ?", "%#{institution_name}%", "%#{name}%")
             .limit(5)
    end
end