class HomeController < ApplicationController
  def index
    @markers = Place.all.map do |place|
      {
        name: place.name,
        address: place.address,
        lat: place.latitude.to_f,
        lng: place.longitude.to_f,
        url: place_path(place)
      }
    end
  end
end
