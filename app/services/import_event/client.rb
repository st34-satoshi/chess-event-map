require "net/http"
require "uri"

module ImportEvent
  class Client
    class RequestError < StandardError; end

    Response = Struct.new(:url, :body, keyword_init: true)

    USER_AGENT = "ChessEventMap/1.0 (+https://github.com/chess-event-map)"
    TIMEOUT_SECONDS = 30
    MAX_REDIRECTS = 5

    def self.get(url)
      fetch(url).body
    end

    def self.fetch(url)
      new.fetch(url)
    end

    def fetch(url)
      uri = parse_uri!(url)
      original_url = uri.to_s

      MAX_REDIRECTS.times do
        response = request(uri)

        if response.is_a?(Net::HTTPRedirection)
          uri = redirect_uri(uri, response["location"])
          next
        end

        unless response.is_a?(Net::HTTPSuccess)
          raise RequestError, "request failed with status #{response.code} for #{original_url}"
        end

        return Response.new(url: uri.to_s, body: response.body)
      end

      raise RequestError, "too many redirects for #{original_url}"
    end

    private

    def parse_uri!(url)
      uri = URI(url)
      raise RequestError, "unsupported URL: #{url}" unless uri.is_a?(URI::HTTP)

      uri
    end

    def request(uri)
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https",
        open_timeout: TIMEOUT_SECONDS, read_timeout: TIMEOUT_SECONDS) do |http|
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = USER_AGENT
        request["Accept"] = "text/html,application/xhtml+xml"
        http.request(request)
      end
    end

    def redirect_uri(current_uri, location)
      raise RequestError, "redirect missing location for #{current_uri}" if location.blank?

      uri = URI.join(current_uri.to_s, location)
      raise RequestError, "unsupported redirect URL: #{location}" unless uri.is_a?(URI::HTTP)

      uri
    rescue URI::InvalidURIError
      raise RequestError, "invalid redirect URL: #{location}"
    end
  end
end
