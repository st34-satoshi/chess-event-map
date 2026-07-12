require "test_helper"

module XApi
  class ClientTest < ActiveSupport::TestCase
    test "returns user profile fields from the API" do
      stub_credentials(bearer_token: "test-token") do
        stub_request(:get, "https://api.x.com/2/users/by/username/JapanChessFed")
          .with(
            query: { "user.fields" => "profile_image_url" },
            headers: { "Authorization" => "Bearer test-token" }
          )
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: {
              data: {
                id: "12345",
                name: "日本チェス連盟",
                username: "JapanChessFed",
                profile_image_url: "https://pbs.twimg.com/profile_images/example_normal.jpg"
              }
            }.to_json
          )

        profile = Client.get_user_by_username("JapanChessFed")

        assert_equal "12345", profile[:x_user_id]
        assert_equal "JapanChessFed", profile[:at_name]
        assert_equal "日本チェス連盟", profile[:display_name]
        assert_equal "https://pbs.twimg.com/profile_images/example_normal.jpg", profile[:profile_image_url]
      end
    end

    test "raises when bearer token is missing" do
      stub_credentials(bearer_token: nil) do
        error = assert_raises(Error) { Client.get_user_by_username("JapanChessFed") }
        assert_equal "X API bearer token is missing", error.message
      end
    end

    test "raises when the user is not found" do
      stub_credentials(bearer_token: "test-token") do
        stub_request(:get, "https://api.x.com/2/users/by/username/missing")
          .with(query: { "user.fields" => "profile_image_url" })
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: {
              errors: [ { title: "Not Found Error", detail: "Could not find user with username: [missing]." } ]
            }.to_json
          )

        error = assert_raises(Error) { Client.get_user_by_username("missing") }
        assert_match(/Could not find user/, error.message)
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
