require "test_helper"

module Claude
  class XPostEventAnalyzerTest < ActiveSupport::TestCase
    test "returns event fields when has_event is true" do
      analysis = XPostEventAnalyzer::AnalysisResult.new(
        has_event: true,
        title: " 名古屋例会 ",
        held_on: "2026-07-05",
        place_name: "アマノ芸術創造センター名古屋",
        place_address: "愛知県名古屋市中区栄1-1",
        detail_url: "https://example.com/event"
      )

      stub_request(analysis) do |captured|
        result = XPostEventAnalyzer.analyze("来週の例会のお知らせ")

        assert result[:has_event]
        assert_equal "名古屋例会", result[:title]
        assert_equal Date.new(2026, 7, 5), result[:held_on]
        assert_equal "アマノ芸術創造センター名古屋", result[:place_name]
        assert_equal "愛知県名古屋市中区栄1-1", result[:place_address]
        assert_equal "https://example.com/event", result[:detail_url]
        assert_includes captured[:user_message], "以下のX投稿を判定してください"
      end
    end

    test "includes existing place names in prompt and returns matched name" do
      analysis = XPostEventAnalyzer::AnalysisResult.new(
        has_event: true,
        title: "名古屋例会",
        held_on: "2026-07-05",
        place_name: "アマノ芸術創造センター名古屋",
        place_address: "愛知県名古屋市中区栄1-1",
        detail_url: nil
      )
      existing_names = [ "アマノ芸術創造センター名古屋", "別の会場" ]

      stub_request(analysis) do |captured|
        result = XPostEventAnalyzer.analyze(
          "来週の例会のお知らせ",
          existing_place_names: existing_names
        )

        user_message = captured[:user_message]
        assert_includes user_message, "既存の会場名一覧:"
        assert_includes user_message, "- アマノ芸術創造センター名古屋"
        assert_includes user_message, "- 別の会場"
        assert_equal "アマノ芸術創造センター名古屋", result[:place_name]
      end
    end

    test "normalizes place name to existing entry when case differs" do
      analysis = XPostEventAnalyzer::AnalysisResult.new(
        has_event: true,
        title: "Test Event",
        held_on: "2026-07-05",
        place_name: "test venue",
        place_address: nil,
        detail_url: nil
      )

      stub_request(analysis) do
        result = XPostEventAnalyzer.analyze(
          "event at test venue",
          existing_place_names: [ "Test Venue" ]
        )

        assert_equal "Test Venue", result[:place_name]
      end
    end

    test "returns has_event false without other fields" do
      analysis = XPostEventAnalyzer::AnalysisResult.new(
        has_event: false,
        title: nil,
        held_on: nil,
        place_name: nil,
        place_address: nil,
        detail_url: nil
      )

      stub_request(analysis) do
        result = XPostEventAnalyzer.analyze("今日の対局楽しかった")

        assert_equal({ has_event: false }, result)
      end
    end

    private

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
