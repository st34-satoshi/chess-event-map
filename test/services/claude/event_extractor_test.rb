require "test_helper"

class Claude::EventExtractorTest < ActiveSupport::TestCase
  setup do
    travel_to Date.new(2026, 7, 12)
  end

  test "extracts detail fields" do
    detail = Claude::EventExtractor::DetailResult.new(
      title: " サマーオープン2026 ",
      held_on: "2026-06-27",
      place_name: "きゅりあん（品川区総合区民会館）",
      place_address: "東京都品川区東大井5-18-1"
    )

    stub_request(detail) do |captured|
      result = Claude::EventExtractor.extract("<html></html>", url: "https://japanchess.org/2026/05/summer2026-2/")
      assert_equal "サマーオープン2026", result[:title]
      assert_equal Date.new(2026, 6, 27), result[:held_on]
      assert_equal "https://japanchess.org/2026/05/summer2026-2/", result[:detail_url]
      assert_equal "きゅりあん（品川区総合区民会館）", result[:place_name]
      assert_equal "東京都品川区東大井5-18-1", result[:place_address]
      assert_includes captured[:user_message], "実行日: 2026-07-12"
      assert_includes captured[:user_message], "以下のHTMLからイベント情報を抽出してください"
      assert_includes captured[:system], "実行日（2026-07-12）に最も近い妥当な年"
    end
  end

  test "includes existing place names in prompt and returns matched name" do
    detail = Claude::EventExtractor::DetailResult.new(
      title: "サマーオープン2026",
      held_on: "2026-06-27",
      place_name: "きゅりあん（品川区総合区民会館）",
      place_address: "東京都品川区東大井5-18-1"
    )
    existing_names = [ "きゅりあん（品川区総合区民会館）", "別の会場" ]

    stub_request(detail) do |captured|
      result = Claude::EventExtractor.extract(
        "<html></html>",
        url: "https://japanchess.org/2026/05/summer2026-2/",
        existing_place_names: existing_names
      )

      user_message = captured[:user_message]
      assert_includes user_message, "既存の会場名一覧:"
      assert_includes user_message, "- きゅりあん（品川区総合区民会館）"
      assert_includes user_message, "- 別の会場"
      assert_equal "きゅりあん（品川区総合区民会館）", result[:place_name]
    end
  end

  test "normalizes place name to existing entry when case differs" do
    detail = Claude::EventExtractor::DetailResult.new(
      title: "サマーオープン2026",
      held_on: "2026-06-27",
      place_name: "test venue",
      place_address: ""
    )

    stub_request(detail) do |_captured|
      result = Claude::EventExtractor.extract(
        "<html></html>",
        url: "https://example.com/event",
        existing_place_names: [ "Test Venue" ]
      )
      assert_equal "Test Venue", result[:place_name]
    end
  end

  test "raises when held_on is more than six months from today" do
    detail = Claude::EventExtractor::DetailResult.new(
      title: "遠すぎる大会",
      held_on: "2025-12-01",
      place_name: "きゅりあん",
      place_address: nil
    )

    stub_request(detail) do
      error = assert_raises(Claude::Error) do
        Claude::EventExtractor.extract("<html></html>", url: "https://example.com/event")
      end
      assert_match(/more than 6 months/, error.message)
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
    captured = {}
    stub_class_method(Claude::Client, :request, ->(user:, format:, system:) {
      captured[:user_message] = user
      captured[:format] = format
      captured[:system] = system
      parsed_output
    }) do
      yield captured
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
