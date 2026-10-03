class CreateXPosting < ActiveRecord::Migration[8.1]
  def change
    create_table :x_posting_accounts do |t|
      t.string :x_user_id, null: false
      t.string :username, null: false
      t.string :name, null: false
      t.text :access_token_ciphertext, null: false
      t.text :refresh_token_ciphertext, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :x_posting_accounts, :x_user_id, unique: true

    create_table :x_posting_settings do |t|
      t.references :x_posting_account, foreign_key: true
      t.timestamps
    end

    create_table :x_publications do |t|
      t.references :event, null: false, foreign_key: true
      t.references :x_posting_account, foreign_key: true
      t.string :request_id, null: false, limit: 100
      t.text :text, null: false
      t.string :status, null: false, default: "pending"
      t.string :x_post_id
      t.string :error_message
      t.timestamps
    end
    add_index :x_publications, :request_id, unique: true
  end
end
