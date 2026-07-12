class CreateXPosts < ActiveRecord::Migration[8.1]
  def change
    create_table :x_posts do |t|
      t.references :x_account, null: false, foreign_key: true
      t.string :x_post_id
      t.text :text
      t.datetime :posted_at
      t.string :url
      t.string :public_uid

      t.timestamps
    end
    add_index :x_posts, :x_post_id, unique: true
    add_index :x_posts, :public_uid, unique: true
  end
end
