module ImportEvent
  class PlaceResolver
    def self.find_or_create!(name:, address:)
      new.find_or_create!(name: name, address: address)
    end

    # Returns [place, place_created].
    def find_or_create!(name:, address:)
      existing_place = Place.find_by(name: name)
      return [ existing_place, false ] if existing_place

      resolved_address = address.presence || Claude::AddressInferrer.infer(place_name: name)
      raise ArgumentError, "geocodable address could not be determined for #{name}" if resolved_address.blank?

      place = Place.new(name: name, address: resolved_address, created_by: :ai)
      place.assign_coordinates_from_address

      existing = Place.find_by(latitude: place.latitude, longitude: place.longitude)
      return [ existing, false ] if existing

      place.save!
      [ place, true ]
    end
  end
end
