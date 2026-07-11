require "net/http"
require "uri"

module ImportEvent
  class Client
    class RequestError < StandardError; end

    USER_AGENT = "ChessEventMap/1.0 (+https://github.com/chess-event-map)"
    TIMEOUT_SECONDS = 30

    def self.get(url)
      new.get(url)
    end

    def get(url)
      uri = URI(url)
      raise RequestError, "unsupported URL: #{url}" unless uri.is_a?(URI::HTTP)

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https",
        open_timeout: TIMEOUT_SECONDS, read_timeout: TIMEOUT_SECONDS) do |http|
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = USER_AGENT
        request["Accept"] = "text/html,application/xhtml+xml"
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise RequestError, "request failed with status #{response.code} for #{url}"
      end

      response.body
    end
  end
end
