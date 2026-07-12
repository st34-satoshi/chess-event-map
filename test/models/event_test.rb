require "test_helper"

class EventTest < ActiveSupport::TestCase
  test "defaults created_by to human" do
    event = Event.new(title: "テスト大会", held_on: Date.new(2026, 1, 1), place: places(:one))

    assert event.human?
  end
end
