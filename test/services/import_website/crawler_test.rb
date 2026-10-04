require "test_helper"

module ImportWebsite
  class CrawlerTest < ActiveSupport::TestCase
    setup do
      @website = websites(:one)
      @html = "<html><body><main><p>10月18日 例会</p></main></body></html>"
      stub_request(:get, @website.url).to_return(status: 200, body: @html)
    end

    test "creates new events and remembers the page digest" do
      stub_analyzer([ analysis(title: "10月例会") ]) do
        assert_difference "Event.count", 1 do
          result = Crawler.call(@website)

          assert_equal :event_created, result.status
          assert_equal [ "10月例会" ], result.created.map(&:title)
        end
      end

      @website.reload
      assert @website.crawl_event_created?
      assert_not_nil @website.content_digest
      assert_not_nil @website.last_crawled_at
      assert_includes @website.last_crawl_message, "10月例会"
    end

    test "skips Claude when the page has not changed" do
      stub_analyzer([]) { Crawler.call(@website) }

      calls = 0
      stub_class_method(Claude::WebsiteEventAnalyzer, :analyze, ->(*, **) { calls += 1; [] }) do
        result = Crawler.call(@website.reload)

        assert_equal :unchanged, result.status
      end
      assert_equal 0, calls
    end

    test "records no_new_event when every event already exists" do
      existing = events(:one)
      stub_analyzer([ analysis(title: existing.title, held_on: existing.held_on, place_name: existing.place.name) ]) do
        result = Crawler.call(@website)

        assert_equal :no_new_event, result.status
        assert_equal [ existing ], result.existing
      end
    end

    test "keeps the old digest when an event fails so the page is retried" do
      stub_analyzer([ analysis(title: "会場不明", place_name: nil) ]) do
        result = Crawler.call(@website)

        assert_equal :failed, result.status
        assert_match "venue name is missing", result.errors.first
      end

      @website.reload
      assert @website.crawl_failed?
      assert_nil @website.content_digest
    end

    test "records fetch failures" do
      stub_request(:get, @website.url).to_return(status: 404)

      result = Crawler.call(@website)

      assert_equal :failed, result.status
      assert_match "404", result.errors.first
      assert @website.reload.crawl_failed?
    end

    private

    def analysis(title:, held_on: Date.new(2026, 10, 18), place_name: places(:one).name)
      { title: title, held_on: held_on, place_name: place_name, place_address: nil, detail_url: nil }
    end

    def stub_analyzer(events, &block)
      stub_class_method(Claude::WebsiteEventAnalyzer, :analyze, ->(_html, url:, existing_place_names: []) { events }, &block)
    end
  end
end
