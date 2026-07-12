require "test_helper"

class NotifySlackOfEventJobTest < ActiveJob::TestCase
  test "notifies Slack with the event details" do
    place = Place.create!(name: "テスト会場", address: "テスト住所", latitude: 35.0, longitude: 135.0)
    event = place.events.create!(title: "テスト大会", held_on: Date.new(2026, 7, 12), url: "https://example.com")

    message = nil
    stub_class_method(SlackNotifier, :notify, ->(text) { message = text }) do
      NotifySlackOfEventJob.perform_now(event.id)
    end

    assert_includes message, event.title
    assert_includes message, event.held_on.to_s
    assert_includes message, place.name
    assert_includes message, "https://chess-event-map.stu345.com/events/#{event.public_uid}"
  end

  test "does nothing when the event no longer exists" do
    stub_class_method(SlackNotifier, :notify, ->(*) { raise "should not be called" }) do
      assert_nothing_raised do
        NotifySlackOfEventJob.perform_now(-1)
      end
    end
  end
end
