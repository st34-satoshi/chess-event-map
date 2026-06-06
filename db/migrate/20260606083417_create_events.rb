class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.string :title
      t.date :held_on
      t.string :url

      t.timestamps
    end
  end
end
