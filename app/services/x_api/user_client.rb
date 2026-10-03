require "net/http"
require "json"
require "base64"
require "digest"

module XApi
  # User context is intentionally separate from the read-only app bearer client.
  class UserClient
    SCOPES = %w[tweet.read tweet.write users.read offline.access].freeze

    def authorization_url(state:, verifier:)
      "https://x.com/i/oauth2/authorize?" + URI.encode_www_form(
        response_type: "code", client_id: configuration(:client_id),
        redirect_uri: configuration(:redirect_uri), scope: SCOPES.join(" "), state: state,
        code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false),
        code_challenge_method: "S256"
      )
    end

    def exchange(code:, verifier:)
      token_request(grant_type: "authorization_code", code: code,
        redirect_uri: configuration(:redirect_uri), code_verifier: verifier)
    end

    def refresh(token)
      token_request(grant_type: "refresh_token", refresh_token: token)
    end

    def me(token)
      uri = URI("https://api.x.com/2/users/me")
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{token}"
      data = perform(uri, request).fetch("data", {})
      unless data.is_a?(Hash) && data["id"].to_s.match?(/\A\d+\z/) && data["username"].present? && data["name"].present?
        raise Error, "X returned an invalid account response"
      end
      data
    end

    def publish(token:, text:)
      uri = URI("https://api.x.com/2/tweets")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{token}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(text: text)
      id = perform(uri, request).dig("data", "id")
      raise Error, "X returned no post ID. Check X before trying another request ID." unless id.is_a?(String) && id.match?(/\A\d+\z/)
      id
    end

    private

    def configuration(key)
      value = Rails.application.credentials.dig(:x, :oauth, key)
      raise Error, "Missing x.oauth.#{key} configuration" if value.blank?
      value
    end

    def token_request(parameters)
      uri = URI("https://api.x.com/2/oauth2/token")
      request = Net::HTTP::Post.new(uri)
      request.basic_auth(configuration(:client_id), configuration(:client_secret))
      request.set_form_data(parameters)
      perform(uri, request)
    end

    def perform(uri, request)
      request["Accept"] = "application/json"
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true,
        open_timeout: 10, read_timeout: 30, write_timeout: 30, max_retries: 0) { |http| http.request(request) }
      # Never expose upstream response bodies: they can contain credentials.
      raise Error, "X API request failed (HTTP #{response.code}). Check authorization, quota and permissions." unless response.is_a?(Net::HTTPSuccess)
      result = JSON.parse(response.body)
      raise Error, "X returned an invalid response" unless result.is_a?(Hash)
      result
    rescue JSON::ParserError
      raise Error, "X returned invalid JSON. Check X before retrying a publication."
    rescue Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError
      raise Error, "X API connection failed. Publication may have succeeded; check X before using a new request ID."
    end
  end
end
