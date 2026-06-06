class ChangeLatitudeLongitudeScaleOnPlaces < ActiveRecord::Migration[8.1]
  def change
    change_column :places, :latitude, :decimal, precision: 10, scale: 7
    change_column :places, :longitude, :decimal, precision: 10, scale: 7
  end
end
