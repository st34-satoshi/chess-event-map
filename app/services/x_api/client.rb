require "json"
require "net/http"
require "uri"

module XApi
  class Client
    BASE_URL = "https://api.x.com/2"
    TIMEOUT_SECONDS = 30

    def self.get_json(uri)
      new.get_json(uri)
    end

    def get_json(uri)
      response = request(uri)
      JSON.parse(response.body)
    end

    private

    def request(uri)
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true,
        open_timeout: TIMEOUT_SECONDS, read_timeout: TIMEOUT_SECONDS) do |http|
        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = "Bearer #{bearer_token}"
        request["Accept"] = "application/json"
        http.request(request)
      end

      return response if response.is_a?(Net::HTTPSuccess)

      detail = begin
        JSON.parse(response.body).dig("errors", 0, "detail")
      rescue JSON::ParserError
        nil
      end

      message = detail.presence || "request failed with status #{response.code}"
      raise Error, message
    end

    def bearer_token
      token = Rails.application.credentials.dig(:x, :bearer_token)
      raise Error, "X API bearer token is missing" if token.blank?

      token
    end
  end
end
