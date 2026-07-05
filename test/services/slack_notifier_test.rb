require "test_helper"

class SlackNotifierTest < ActiveSupport::TestCase
  test "does not raise and skips the request when credentials are missing" do
    Rails.application.credentials.stub :slack_api_token, nil do
      assert_nothing_raised { SlackNotifier.notify("hello") }
    end
  end

  test "posts to the Slack API when credentials are present" do
    response = Net::HTTPSuccess.new("1.1", "200", "OK")
    response.define_singleton_method(:body) { '{"ok":true}' }

    request_body = nil
    http_double = Object.new
    http_double.define_singleton_method(:request) { |req| request_body = req.body; response }

    Rails.application.credentials.stub :slack_api_token, "test-token" do
      Rails.application.credentials.stub :slack_channel, "#general" do
        Net::HTTP.stub :start, ->(*_args, &block) { block.call(http_double) } do
          SlackNotifier.notify("修正依頼が届きました")
        end
      end
    end

    payload = JSON.parse(request_body)
    assert_equal "#general", payload["channel"]
    assert_equal "修正依頼が届きました", payload["text"]
  end
end
