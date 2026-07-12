require "uri"

module XApi
  class UserFetcher
    USER_FIELDS = "profile_image_url"

    def self.get_by_username(username)
      new.get_by_username(username)
    end

    def get_by_username(username)
      raise Error, "username is blank" if username.blank?

      uri = URI("#{Client::BASE_URL}/users/by/username/#{URI.encode_uri_component(username)}")
      uri.query = URI.encode_www_form("user.fields" => USER_FIELDS)

      body = Client.get_json(uri)
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
  end
end
