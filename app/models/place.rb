class Place < ApplicationRecord
  validates :address, presence: true
  validates :name, :latitude, :longitude, presence: true

  def assign_coordinates_from_address
    geocoded = PlaceGeocoder.lookup(address)
    assign_attributes(
      address: geocoded[:address],
      latitude: geocoded[:latitude],
      longitude: geocoded[:longitude]
    )
  end
end
