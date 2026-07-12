require "test_helper"

module XApi
  class TweetFetcherTest < ActiveSupport::TestCase
    test "returns user tweets across pages" do
      stub_credentials(bearer_token: "test-token") do
        stub_request(:get, "https://api.x.com/2/users/111/tweets")
          .with(
            query: hash_including("tweet.fields" => "created_at", "max_results" => "100", "since_id" => "100"),
            headers: { "Authorization" => "Bearer test-token" }
          )
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: {
              data: [
                { id: "101", text: "newer", created_at: "2026-07-12T01:00:00.000Z" }
              ],
              meta: { next_token: "page-2" }
            }.to_json
          )

        stub_request(:get, "https://api.x.com/2/users/111/tweets")
          .with(
            query: hash_including(
              "tweet.fields" => "created_at",
              "max_results" => "100",
              "since_id" => "100",
              "pagination_token" => "page-2"
            )
          )
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: {
              data: [
                { id: "102", text: "newest", created_at: "2026-07-12T02:00:00.000Z" }
              ],
              meta: { result_count: 1 }
            }.to_json
          )

        tweets = TweetFetcher.get_for_user("111", since_id: "100")

        assert_equal [ "101", "102" ], tweets.map { |t| t[:x_post_id] }
        assert_equal "newer", tweets.first[:text]
        assert_equal Time.zone.parse("2026-07-12T01:00:00.000Z"), tweets.first[:posted_at]
      end
    end

    private

    def stub_credentials(bearer_token:)
      x = ActiveSupport::OrderedOptions.new
      x.bearer_token = bearer_token

      credentials = ActiveSupport::OrderedOptions.new
      credentials.x = x

      application = Rails.application
      original = application.method(:credentials)
      application.define_singleton_method(:credentials) { credentials }
      yield
    ensure
      application.define_singleton_method(:credentials, original) if original
    end
  end
end
