class CreateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :items do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.integer :cycle_days
      t.date :cycle_changed_on

      t.timestamps
    end
  end
end
