require "test_helper"

class Claude::EventExtractorTest < ActiveSupport::TestCase
  test "extracts detail fields" do
    detail = Claude::EventExtractor::DetailResult.new(
      title: " サマーオープン2026 ",
      held_on: "2026-06-27",
      place_name: "きゅりあん（品川区総合区民会館）",
      place_address: "東京都品川区東大井5-18-1"
    )

    stub_request(detail) do
      result = Claude::EventExtractor.extract("<html></html>", url: "https://japanchess.org/2026/05/summer2026-2/")
      assert_equal "サマーオープン2026", result[:title]
      assert_equal Date.new(2026, 6, 27), result[:held_on]
      assert_equal "https://japanchess.org/2026/05/summer2026-2/", result[:detail_url]
      assert_equal "きゅりあん（品川区総合区民会館）", result[:place_name]
      assert_equal "東京都品川区東大井5-18-1", result[:place_address]
    end
  end

  test "raises when anthropic api key is missing" do
    stub_credentials(api_key: nil) do
      assert_raises(Claude::Error) do
        Claude::EventExtractor.extract("<html></html>", url: "https://example.com/")
      end
    end
  end

  private

  def stub_request(parsed_output)
    message = Object.new
    message.define_singleton_method(:parsed_output) { parsed_output }

    messages = Object.new
    messages.define_singleton_method(:create) { |**_kwargs| message }

    client = Object.new
    client.define_singleton_method(:messages) { messages }

    stub_credentials(api_key: "test-key") do
      original_client = Claude::Client.method(:client)
      Claude::Client.define_singleton_method(:client) { client }
      begin
        yield
      ensure
        Claude::Client.define_singleton_method(:client, original_client)
      end
    end
  end

  def stub_credentials(api_key:)
    anthropic = ActiveSupport::OrderedOptions.new
    anthropic.api_key = api_key

    credentials = ActiveSupport::OrderedOptions.new
    credentials.anthropic = anthropic

    application = Rails.application
    original = application.method(:credentials)
    application.define_singleton_method(:credentials) { credentials }
    yield
  ensure
    application.define_singleton_method(:credentials, original) if original
  end
end
