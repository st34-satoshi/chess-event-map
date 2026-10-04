require "test_helper"

module Claude
  class WebsiteEventAnalyzerTest < ActiveSupport::TestCase
    setup do
      travel_to Date.new(2026, 10, 4)
    end

    test "returns upcoming events with absolute detail urls" do
      analysis = WebsiteEventAnalyzer::AnalysisResult.new(
        events: [
          event_item(title: " 10月例会 ", held_on: "2026-10-18", place_name: "区民会館", detail_url: "/events/oct"),
          event_item(title: "9月例会", held_on: "2026-09-20", place_name: "区民会館"),
          event_item(title: "日付不明", held_on: "unknown"),
          event_item(title: "遠すぎる大会", held_on: "2027-12-01")
        ]
      )

      stub_request(analysis) do |captured|
        events = WebsiteEventAnalyzer.analyze("<p>例会</p>", url: "https://club.example.com/top")

        assert_equal 1, events.size
        assert_equal "10月例会", events.first[:title]
        assert_equal Date.new(2026, 10, 18), events.first[:held_on]
        assert_equal "区民会館", events.first[:place_name]
        assert_equal "https://club.example.com/events/oct", events.first[:detail_url]
        assert_includes captured[:user_message], "ページURL: https://club.example.com/top"
        assert_includes captured[:user_message], "実行日: 2026-10-04"
      end
    end

    test "matches place names to existing entries" do
      analysis = WebsiteEventAnalyzer::AnalysisResult.new(
        events: [ event_item(title: "例会", held_on: "2026-10-18", place_name: "kyurian") ]
      )

      stub_request(analysis) do |captured|
        events = WebsiteEventAnalyzer.analyze("<p>例会</p>", url: "https://club.example.com/",
          existing_place_names: [ "Kyurian" ])

        assert_equal "Kyurian", events.first[:place_name]
        assert_includes captured[:user_message], "- Kyurian"
      end
    end

    test "returns empty list when no events are found" do
      stub_request(WebsiteEventAnalyzer::AnalysisResult.new(events: [])) do
        assert_empty WebsiteEventAnalyzer.analyze("<p>ようこそ</p>", url: "https://club.example.com/")
      end
    end

    test "raises when page content is blank" do
      assert_raises(Claude::Error) do
        WebsiteEventAnalyzer.analyze("", url: "https://club.example.com/")
      end
    end

    private

    def event_item(title:, held_on:, place_name: nil, place_address: nil, detail_url: nil)
      WebsiteEventAnalyzer::EventItem.new(
        title: title, held_on: held_on, place_name: place_name,
        place_address: place_address, detail_url: detail_url
      )
    end

    def stub_request(analysis)
      captured = {}
      stub_class_method(Client, :request, ->(user:, format:, system:) {
        captured[:user_message] = user
        captured[:format] = format
        captured[:system] = system
        analysis
      }) do
        yield captured
      end
    end
  end
end
