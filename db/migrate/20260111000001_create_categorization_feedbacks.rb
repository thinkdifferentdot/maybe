class CreateCategorizationFeedbacks < ActiveRecord::Migration[7.2]
  def change
    create_table :categorization_feedbacks, id: :uuid do |t|
      t.uuid :family_id, null: false, index: true
      t.uuid :txn_id, null: false, index: true
      t.uuid :suggested_category_id, null: false
      t.uuid :final_category_id

      t.timestamps
    end

    add_index :categorization_feedbacks, [ :family_id, :created_at ]
    add_index :categorization_feedbacks, [ :suggested_category_id, :final_category_id ]
  end
end
