class CreateWebsites < ActiveRecord::Migration[8.1]
  def change
    create_table :websites do |t|
      t.string :name, null: false
      t.string :url, null: false
      t.references :x_account, foreign_key: { on_delete: :nullify }
      t.string :public_uid, null: false

      t.timestamps
    end
    add_index :websites, :url, unique: true
    add_index :websites, :public_uid, unique: true
  end
end
