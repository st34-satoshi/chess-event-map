class CreatePlaces < ActiveRecord::Migration[8.1]
  def change
    create_table :places do |t|
      t.string :name
      t.text :address
      t.decimal :latitude
      t.decimal :longitude

      t.timestamps
    end
  end
end
