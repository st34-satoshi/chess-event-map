class AddEventDetectionStatusToXPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :x_posts, :event_detection_status, :string, null: false, default: "pending"
    add_index :x_posts, :event_detection_status
  end
end
