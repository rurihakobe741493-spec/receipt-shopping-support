class CreateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :items do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.integer :cycle_days, null: false, default: 30
      t.date :cycle_changed_on

      t.timestamps
    end

    add_index :items, [ :user_id, :name ], unique: true
  end
end
