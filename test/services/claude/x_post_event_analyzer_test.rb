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

      stub_request(analysis) do
        result = XPostEventAnalyzer.analyze("来週の例会のお知らせ")

        assert result[:has_event]
        assert_equal "名古屋例会", result[:title]
        assert_equal Date.new(2026, 7, 5), result[:held_on]
        assert_equal "アマノ芸術創造センター名古屋", result[:place_name]
        assert_equal "愛知県名古屋市中区栄1-1", result[:place_address]
        assert_equal "https://example.com/event", result[:detail_url]
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
      captured = nil
      stub_class_method(Client, :request, ->(user:, format:, system:) {
        captured = { user_message: user, format: format, system: system }
        analysis
      }) do
        yield captured
      end
    end
  end
end
