require "test_helper"

class Claude::AddressInferrerTest < ActiveSupport::TestCase
  test "infers geocodable address from place name" do
    address_result = Claude::AddressInferrer::AddressResult.new(
      address: "東京都品川区東大井5-18-1"
    )

    stub_request(address_result) do
      assert_equal "東京都品川区東大井5-18-1",
        Claude::AddressInferrer.infer(place_name: "きゅりあん（品川区総合区民会館）")
    end
  end

  private

  def stub_request(parsed_output)
    message = Object.new
    message.define_singleton_method(:parsed_output) { parsed_output }

    messages = Object.new
    messages.define_singleton_method(:create) { |**_kwargs| message }

    client = Object.new
    client.define_singleton_method(:messages) { messages }

    stub_credentials(api_key: "test-key") do
      original_client = Claude::Client.method(:client)
      Claude::Client.define_singleton_method(:client) { client }
      begin
        yield
      ensure
        Claude::Client.define_singleton_method(:client, original_client)
      end
    end
  end

  def stub_credentials(api_key:)
    anthropic = ActiveSupport::OrderedOptions.new
    anthropic.api_key = api_key

    credentials = ActiveSupport::OrderedOptions.new
    credentials.anthropic = anthropic

    application = Rails.application
    original = application.method(:credentials)
    application.define_singleton_method(:credentials) { credentials }
    yield
  ensure
    application.define_singleton_method(:credentials, original) if original
  end
end
