require "uri"

module XApi
  class TweetFetcher
    TWEET_FIELDS = "created_at"
    MAX_RESULTS = 100

    def self.get_for_user(user_id, since_id: nil, start_time: nil)
      new.get_for_user(user_id, since_id: since_id, start_time: start_time)
    end

    def get_for_user(user_id, since_id: nil, start_time: nil)
      raise Error, "user_id is blank" if user_id.blank?

      tweets = []
      pagination_token = nil

      loop do
        params = {
          "tweet.fields" => TWEET_FIELDS,
          "max_results" => MAX_RESULTS
        }
        params["since_id"] = since_id if since_id.present?
        params["start_time"] = start_time.utc.iso8601 if start_time
        params["pagination_token"] = pagination_token if pagination_token.present?

        uri = URI("#{Client::BASE_URL}/users/#{URI.encode_uri_component(user_id)}/tweets")
        uri.query = URI.encode_www_form(params)

        body = Client.get_json(uri)
        Array(body["data"]).each do |tweet|
          tweets << {
            x_post_id: tweet.fetch("id"),
            text: tweet.fetch("text"),
            posted_at: Time.zone.parse(tweet.fetch("created_at"))
          }
        end

        pagination_token = body.dig("meta", "next_token")
        break if pagination_token.blank?
      end

      tweets
    end
  end
end
