class CreateLearnedPatterns < ActiveRecord::Migration[7.2]
  def change
    create_table :learned_patterns, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, index: true, type: :uuid
      t.references :category, null: false, foreign_key: true, index: true, type: :uuid
      t.string :merchant_name, null: false
      t.string :normalized_merchant, null: false
      t.timestamps

      t.index [ :family_id, :normalized_merchant ], unique: true
    end
  end
end
