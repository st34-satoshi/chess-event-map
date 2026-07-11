require "test_helper"

class NoExternalNetworkTest < ActiveSupport::TestCase
  test "blocks unstubbed external http requests" do
    assert_raises(WebMock::NetConnectNotAllowedError) do
      Net::HTTP.get(URI("https://example.com/"))
    end
  end
end
