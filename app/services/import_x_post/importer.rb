module ImportXPost
  class Importer
    LOOKBACK = 1.month

    Result = Struct.new(:created, :skipped, keyword_init: true)

    def self.call
      new.call
    end

    def call
      created = []
      skipped = []

      XAccount.find_each do |account|
        import_account(account, created: created, skipped: skipped)
      end

      Result.new(created: created, skipped: skipped)
    end

    private

    def import_account(account, created:, skipped:)
      tweets = fetch_tweets(account)

      tweets.each do |tweet|
        if XPost.exists?(x_post_id: tweet[:x_post_id])
          skipped << tweet[:x_post_id]
          next
        end

        created << XPost.create!(
          x_account: account,
          x_post_id: tweet[:x_post_id],
          text: tweet[:text],
          posted_at: tweet[:posted_at],
          url: post_url(account, tweet[:x_post_id])
        )
      end
    end

    def fetch_tweets(account)
      latest = account.x_posts.order(posted_at: :desc, id: :desc).first

      if latest.nil? || latest.posted_at < LOOKBACK.ago
        XApi::TweetFetcher.get_for_user(account.x_user_id, start_time: LOOKBACK.ago)
      else
        XApi::TweetFetcher.get_for_user(account.x_user_id, since_id: latest.x_post_id)
      end
    end

    def post_url(account, x_post_id)
      "https://x.com/#{account.at_name}/status/#{x_post_id}"
    end
  end
end
