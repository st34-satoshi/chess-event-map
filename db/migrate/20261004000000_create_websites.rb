class CreateWebsites < ActiveRecord::Migration[8.1]
  def change
    create_table :websites do |t|
      t.string :name, null: false
      t.string :url, null: false
      t.references :x_account, foreign_key: { on_delete: :nullify }
      t.boolean :active, default: true, null: false
      t.string :public_uid, null: false
      t.string :content_digest
      t.datetime :last_crawled_at
      t.string :last_crawl_status
      t.text :last_crawl_message

      t.timestamps
    end
    add_index :websites, :url, unique: true
    add_index :websites, :public_uid, unique: true
  end
end
