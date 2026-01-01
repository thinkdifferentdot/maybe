class LunchflowAccount < ApplicationRecord
  belongs_to :lunchflow_connection
  belongs_to :account, optional: true

  validates :lunchflow_id, presence: true, uniqueness: true
  validates :name, :institution_name, :provider, presence: true

  def ensure_account!
    return account if account.present?

    new_account = Account.create!(
      family: lunchflow_connection.family,
      name: "#{institution_name} - #{name}",
      currency: currency || lunchflow_connection.family.currency || "USD",
      balance: 0,
      accountable: Depository.new
    )

    update!(account: new_account)
    new_account
  end

  def potential_duplicates
    Account.where(family: lunchflow_connection.family)
           .where("name ILIKE ? OR name ILIKE ?", "%#{institution_name}%", "%#{name}%")
           .limit(5)
  end
end
