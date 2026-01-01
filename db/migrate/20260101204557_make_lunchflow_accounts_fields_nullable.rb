class MakeLunchflowAccountsFieldsNullable < ActiveRecord::Migration[7.2]
  def change
    change_column_null :lunchflow_accounts, :currency, true
    change_column_null :lunchflow_accounts, :status, true
  end
end