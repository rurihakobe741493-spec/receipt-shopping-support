class CreatePurchases < ActiveRecord::Migration[8.1]
  def change
    create_table :purchases do |t|
      t.references :item, null: false, foreign_key: true, index: false
      t.date :purchased_on, null: false
      t.string :receipt_name, null: false

      t.timestamps
    end

    add_index :purchases, [ :item_id, :purchased_on ]
  end
end
