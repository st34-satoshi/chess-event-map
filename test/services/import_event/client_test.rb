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
  end
end
