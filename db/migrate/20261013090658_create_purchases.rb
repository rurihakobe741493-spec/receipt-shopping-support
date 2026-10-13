class CreatePurchases < ActiveRecord::Migration[8.1]
  def change
    create_table :purchases do |t|
      t.references :item, null: false, foreign_key: true
      t.date :purchased_on
      t.string :receipt_name

      t.timestamps
    end
  end
end
