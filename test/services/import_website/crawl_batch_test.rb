require "test_helper"

module ImportWebsite
  class CrawlBatchTest < ActiveSupport::TestCase
    test "crawls active websites and notifies Slack" do
      messages = []
      crawled = []
      event = events(:one)

      stub_class_method(SlackNotifier, :notify, ->(text) { messages << text }) do
        stub_class_method(Crawler, :call, lambda { |website|
          crawled << website
          Crawler::Result.new(status: :event_created, website: website, created: [ event ], existing: [], errors: [])
        }) do
          result = CrawlBatch.call

          assert_equal 1, result.website_count
          assert_equal 1, result.counts[:event_created]
        end
      end

      assert_equal [ websites(:one) ], crawled
      assert_equal 2, messages.size
      assert_includes messages.first, "対象: 1件"
      assert_includes messages.last, event.title
    end
  end
end
