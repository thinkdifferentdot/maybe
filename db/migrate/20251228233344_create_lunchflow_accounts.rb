class CreateLunchflowAccounts < ActiveRecord::Migration[7.2]
  def change
    create_table :lunchflow_accounts, id: :uuid do |t|
      t.references :lunchflow_connection, null: false, foreign_key: true, type: :uuid
      t.references :account, null: true, foreign_key: true, type: :uuid
      t.bigint :lunchflow_id, null: false
      t.string :name, null: false
      t.string :institution_name, null: false
      t.string :institution_logo
      t.string :provider, null: false
      t.string :currency, null: false
      t.string :status, null: false
      t.timestamps

      t.index :lunchflow_id, unique: true
    end
  end
end
