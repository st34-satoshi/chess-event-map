require "test_helper"

class NotifySlackOfPlaceJobTest < ActiveJob::TestCase
  test "notifies Slack with the place details" do
    place = Place.create!(name: "テスト会場", address: "テスト住所", latitude: 35.0, longitude: 135.0)

    message = nil
    stub_class_method(SlackNotifier, :notify, ->(text) { message = text }) do
      NotifySlackOfPlaceJob.perform_now(place.id)
    end

    assert_includes message, place.name
    assert_includes message, place.address
  end

  test "does nothing when the place no longer exists" do
    stub_class_method(SlackNotifier, :notify, ->(*) { raise "should not be called" }) do
      assert_nothing_raised do
        NotifySlackOfPlaceJob.perform_now(-1)
      end
    end
  end
end
