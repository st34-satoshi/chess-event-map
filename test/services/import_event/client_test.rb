require "test_helper"

module ImportEvent
  class ClientTest < ActiveSupport::TestCase
    test "returns response body on success" do
      response = Net::HTTPSuccess.new("1.1", "200", "OK")
      response.define_singleton_method(:body) { "<html>ok</html>" }

      http_double = Object.new
      http_double.define_singleton_method(:request) { |_req| response }

      original_start = Net::HTTP.method(:start)
      Net::HTTP.singleton_class.define_method(:start) { |*_args, **_kwargs, &block| block.call(http_double) }

      begin
        assert_equal "<html>ok</html>", Client.get("https://japanchess.org/2026/05/summer2026-2/")
      ensure
        Net::HTTP.singleton_class.define_method(:start, original_start)
      end
    end

    test "follows redirects and returns the final url" do
      redirect = Net::HTTPMovedPermanently.new("1.1", "301", "Moved Permanently")
      redirect["location"] = "https://example.com/events/nagoya"

      success = Net::HTTPSuccess.new("1.1", "200", "OK")
      success.define_singleton_method(:body) { "<html>final</html>" }

      responses = {
        "t.co" => redirect,
        "example.com" => success
      }

      original_start = Net::HTTP.method(:start)
      Net::HTTP.singleton_class.define_method(:start) do |host, *_args, **_kwargs, &block|
        http_double = Object.new
        http_double.define_singleton_method(:request) { |_req| responses.fetch(host) }
        block.call(http_double)
      end

      begin
        result = Client.fetch("https://t.co/3cFeQZnMCg")
        assert_equal "https://example.com/events/nagoya", result.url
        assert_equal "<html>final</html>", result.body
      ensure
        Net::HTTP.singleton_class.define_method(:start, original_start)
      end
    end

    test "raises when request fails" do
      response = Net::HTTPNotFound.new("1.1", "404", "Not Found")
      response.define_singleton_method(:body) { "missing" }

      http_double = Object.new
      http_double.define_singleton_method(:request) { |_req| response }

      original_start = Net::HTTP.method(:start)
      Net::HTTP.singleton_class.define_method(:start) { |*_args, **_kwargs, &block| block.call(http_double) }

      begin
        assert_raises(Client::RequestError) do
          Client.get("https://japanchess.org/missing/")
        end
      ensure
        Net::HTTP.singleton_class.define_method(:start, original_start)
      end
    end

    test "raises when redirect loop exceeds the limit" do
      redirect = Net::HTTPMovedPermanently.new("1.1", "301", "Moved Permanently")
      redirect["location"] = "https://t.co/loop"

      http_double = Object.new
      http_double.define_singleton_method(:request) { |_req| redirect }

      original_start = Net::HTTP.method(:start)
      Net::HTTP.singleton_class.define_method(:start) { |*_args, **_kwargs, &block| block.call(http_double) }

      begin
        error = assert_raises(Client::RequestError) do
          Client.fetch("https://t.co/loop")
        end
        assert_includes error.message, "too many redirects"
      ensure
        Net::HTTP.singleton_class.define_method(:start, original_start)
      end
    end
  end
end
