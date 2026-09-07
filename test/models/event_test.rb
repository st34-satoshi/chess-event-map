require "test_helper"

class EventTest < ActiveSupport::TestCase
  test "defaults created_by to human" do
    event = Event.new(title: "テスト大会", held_on: Date.new(2026, 1, 1), place: places(:one))

    assert event.human?
  end

  test "rejects duplicate held_on and place" do
    existing = events(:one)
    event = Event.new(
      title: "重複大会",
      held_on: existing.held_on,
      place: existing.place
    )

    assert_not event.valid?
    assert_includes event.errors[:held_on], "と同じ会場のイベントはすでに登録されています"
  end

  test "accepts a blank x_post_url" do
    event = events(:one)
    event.x_post_url = ""

    assert event.valid?
  end

  test "rejects an invalid x_post_url" do
    event = events(:one)
    event.x_post_url = "not-a-url"

    assert_not event.valid?
    assert event.errors[:x_post_url].any?
  end
end
