require "test_helper"

class SlackNotifierTest < ActiveSupport::TestCase
  test "reports missing credentials to Sentry and skips the request" do
    captured = nil
    original = Sentry.method(:capture_message)
    Sentry.singleton_class.define_method(:capture_message) do |message, **options|
      captured = { message: message, options: options }
    end

    begin
      stub_credentials(slack_api_token: nil, slack_channel: nil) do
        assert_nothing_raised { SlackNotifier.notify("hello") }
      end
    ensure
      Sentry.singleton_class.define_method(:capture_message, original)
    end

    assert_equal "Slack credentials are missing", captured[:message]
    assert_equal false, captured[:options][:extra][:token_present]
    assert_equal false, captured[:options][:extra][:channel_present]
  end

  test "posts to the Slack API when credentials are present" do
    response = Net::HTTPSuccess.new("1.1", "200", "OK")
    response.define_singleton_method(:body) { '{"ok":true}' }

    request_body = nil
    http_double = Object.new
    http_double.define_singleton_method(:request) { |req| request_body = req.body; response }

    stub_credentials(slack_api_token: "test-token", slack_channel: "#general") do
      original_start = Net::HTTP.method(:start)
      Net::HTTP.singleton_class.define_method(:start) { |*_args, &block| block.call(http_double) }

      begin
        SlackNotifier.notify("修正依頼が届きました")
      ensure
        Net::HTTP.singleton_class.define_method(:start, original_start)
      end
    end

    payload = JSON.parse(request_body)
    assert_equal "#general", payload["channel"]
    assert_equal "修正依頼が届きました", payload["text"]
  end

  test "raises when the Slack API request fails" do
    stub_credentials(slack_api_token: "test-token", slack_channel: "#general") do
      original_start = Net::HTTP.method(:start)
      Net::HTTP.singleton_class.define_method(:start) { |*_args, &block| raise SocketError, "connection failed" }

      begin
        assert_raises(SocketError) { SlackNotifier.notify("hello") }
      ensure
        Net::HTTP.singleton_class.define_method(:start, original_start)
      end
    end
  end

  private

  def stub_credentials(slack_api_token:, slack_channel:)
    credentials = ActiveSupport::OrderedOptions.new
    credentials.slack_api_token = slack_api_token
    credentials.slack_channel = slack_channel

    application = Rails.application
    original = application.method(:credentials)
    application.define_singleton_method(:credentials) { credentials }
    yield
  ensure
    application.define_singleton_method(:credentials, original) if original
  end
end
