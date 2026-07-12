class AddCreatedByToEventsAndPlaces < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :created_by, :string, null: false, default: "human"
    add_column :places, :created_by, :string, null: false, default: "human"
  end
end
