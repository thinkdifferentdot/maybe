class CreateLunchflowConnections < ActiveRecord::Migration[7.2]
  def change
    create_table :lunchflow_connections, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :status, default: 'active', null: false
      t.datetime :last_synced_at
      t.timestamps
    end
  end
end
