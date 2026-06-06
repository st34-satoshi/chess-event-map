require "net/http"
require "uri"

class PlaceGeocoder
  class GeocodingError < StandardError; end

  API_URL = "https://www.geocoding.jp/api/"

  def self.lookup(address)
    uri = URI(API_URL)
    uri.query = URI.encode_www_form(q: address)

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(Net::HTTP::Get.new(uri))
    end

    raise GeocodingError, "request failed with status #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    result = Hash.from_xml(response.body).fetch("result")
    if result["error"]
      raise GeocodingError, "geocoding error #{result['error']} for address: #{address}"
    end

    coordinate = result["coordinate"]
    raise GeocodingError, "no coordinates found for address: #{address}" unless coordinate

    {
      address: result["google_maps"].presence || result["address"],
      latitude: coordinate["lat"],
      longitude: coordinate["lng"]
    }
  end
end
