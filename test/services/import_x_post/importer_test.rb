require "test_helper"

module ImportXPost
  class ImporterTest < ActiveSupport::TestCase
    setup do
      XPost.delete_all
      XAccount.delete_all
      @account = XAccount.create!(
        at_name: "JapanChessFed",
        x_user_id: "111",
        display_name: "日本チェス連盟"
      )
    end

    test "fetches posts since the latest saved post id" do
      XPost.create!(
        x_account: @account,
        x_post_id: "100",
        text: "existing",
        posted_at: 1.day.ago,
        url: "https://x.com/JapanChessFed/status/100"
      )

      fetched = nil
      stub_class_method(XApi::TweetFetcher, :get_for_user, ->(user_id, since_id: nil, start_time: nil) {
        fetched = { user_id: user_id, since_id: since_id, start_time: start_time }
        [
          {
            x_post_id: "101",
            text: "new post",
            posted_at: Time.zone.parse("2026-07-12T03:00:00Z")
          }
        ]
      }) do
        assert_difference("XPost.count", 1) do
          result = Importer.call

          assert_equal 1, result.created.size
          assert_empty result.skipped
          post = result.created.first
          assert_equal "101", post.x_post_id
          assert_equal "https://x.com/JapanChessFed/status/101", post.url
        end
      end

      assert_equal "111", fetched[:user_id]
      assert_equal "100", fetched[:since_id]
      assert_nil fetched[:start_time]
    end

    test "fetches posts from the last month when no posts exist" do
      fetched = nil
      stub_class_method(XApi::TweetFetcher, :get_for_user, ->(user_id, since_id: nil, start_time: nil) {
        fetched = { user_id: user_id, since_id: since_id, start_time: start_time }
        [
          {
            x_post_id: "201",
            text: "within a month",
            posted_at: Time.zone.parse("2026-07-01T00:00:00Z")
          }
        ]
      }) do
        assert_difference("XPost.count", 1) do
          result = Importer.call
          assert_equal [ "201" ], result.created.map(&:x_post_id)
        end
      end

      assert_equal "111", fetched[:user_id]
      assert_nil fetched[:since_id]
      assert_in_delta 1.month.ago.to_i, fetched[:start_time].to_i, 5
    end

    test "fetches posts from the last month when latest post is older than one month" do
      XPost.create!(
        x_account: @account,
        x_post_id: "50",
        text: "old",
        posted_at: 2.months.ago,
        url: "https://x.com/JapanChessFed/status/50"
      )

      fetched = nil
      stub_class_method(XApi::TweetFetcher, :get_for_user, ->(user_id, since_id: nil, start_time: nil) {
        fetched = { user_id: user_id, since_id: since_id, start_time: start_time }
        [
          {
            x_post_id: "301",
            text: "recent again",
            posted_at: Time.zone.parse("2026-07-10T00:00:00Z")
          }
        ]
      }) do
        assert_difference("XPost.count", 1) do
          result = Importer.call
          assert_equal [ "301" ], result.created.map(&:x_post_id)
        end
      end

      assert_nil fetched[:since_id]
      assert_not_nil fetched[:start_time]
    end

    test "skips already saved post ids" do
      XPost.create!(
        x_account: @account,
        x_post_id: "100",
        text: "existing",
        posted_at: 1.day.ago,
        url: "https://x.com/JapanChessFed/status/100"
      )

      stub_class_method(XApi::TweetFetcher, :get_for_user, ->(_user_id, since_id: nil, start_time: nil) {
        [
          {
            x_post_id: "100",
            text: "duplicate",
            posted_at: Time.zone.parse("2026-07-12T03:00:00Z")
          },
          {
            x_post_id: "101",
            text: "new post",
            posted_at: Time.zone.parse("2026-07-12T04:00:00Z")
          }
        ]
      }) do
        assert_difference("XPost.count", 1) do
          result = Importer.call

          assert_equal [ "101" ], result.created.map(&:x_post_id)
          assert_equal [ "100" ], result.skipped
        end
      end
    end
  end
end
