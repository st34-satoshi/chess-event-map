class CreateXAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :x_accounts do |t|
      t.string :at_name
      t.string :x_user_id
      t.string :display_name
      t.string :profile_image_url
      t.string :public_uid

      t.timestamps
    end
    add_index :x_accounts, :at_name, unique: true
    add_index :x_accounts, :x_user_id, unique: true
    add_index :x_accounts, :public_uid, unique: true
  end
end
