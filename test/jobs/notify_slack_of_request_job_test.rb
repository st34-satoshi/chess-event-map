require "test_helper"

class NotifySlackOfRequestJobTest < ActiveJob::TestCase
  test "notifies Slack with the request details" do
    place = Place.create!(name: "テスト会場", address: "テスト住所", latitude: 35.0, longitude: 135.0)
    request = place.requests.create!(comment: "住所が間違っています")

    message = nil
    stub_class_method(SlackNotifier, :notify, ->(text) { message = text }) do
      NotifySlackOfRequestJob.perform_now(request.id)
    end

    assert_includes message, "Place"
    assert_includes message, place.name
    assert_includes message, "住所が間違っています"
  end

  test "does nothing when the request no longer exists" do
    stub_class_method(SlackNotifier, :notify, ->(*) { raise "should not be called" }) do
      assert_nothing_raised do
        NotifySlackOfRequestJob.perform_now(-1)
      end
    end
  end
end
