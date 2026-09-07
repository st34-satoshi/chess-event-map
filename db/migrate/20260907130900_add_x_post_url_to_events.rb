class AddXPostUrlToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :x_post_url, :string
  end
end
