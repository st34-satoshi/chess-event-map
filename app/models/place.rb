class Place < ApplicationRecord
  include PublicUid

  has_many :events, dependent: :restrict_with_error

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
