require "json"
require "net/http"
require "uri"

module XApi
  class Client
    BASE_URL = "https://api.x.com/2"
    TIMEOUT_SECONDS = 30
    USER_FIELDS = "profile_image_url"

    def self.get_user_by_username(username)
      new.get_user_by_username(username)
    end

    def get_user_by_username(username)
      raise Error, "username is blank" if username.blank?

      uri = URI("#{BASE_URL}/users/by/username/#{URI.encode_uri_component(username)}")
      uri.query = URI.encode_www_form("user.fields" => USER_FIELDS)

      response = request(uri)
      body = JSON.parse(response.body)
      data = body["data"]

      unless data.is_a?(Hash) && data["id"].present?
        detail = body.dig("errors", 0, "detail") || body.dig("errors", 0, "title") || "user not found"
        raise Error, "failed to lookup @#{username}: #{detail}"
      end

      {
        x_user_id: data.fetch("id"),
        at_name: data.fetch("username"),
        display_name: data.fetch("name"),
        profile_image_url: data["profile_image_url"]
      }
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
