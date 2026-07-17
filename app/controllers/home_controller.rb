class HomeController < ApplicationController
  def index
    @from = parse_date(params[:from])
    @to = parse_date(params[:to])

    places = if @from || @to
      Place.with_events_held_between(@from, @to)
    else
      Place.all
    end

    @markers = places.map do |place|
      {
        name: place.name,
        address: place.address,
        lat: place.latitude.to_f,
        lng: place.longitude.to_f,
        url: place_path(place)
      }
    end
  end

  private

  def parse_date(value)
    return if value.blank?

    Date.iso8601(value)
  rescue ArgumentError
    nil
  end
end
