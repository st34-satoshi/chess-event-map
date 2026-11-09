require "test_helper"

class PlacesControllerTest < ActionDispatch::IntegrationTest
  test "show excludes cancelled events while keeping other events" do
    event = events(:one)
    event.update!(cancelled: true)
    active = Event.create!(title: "開催予定の大会", held_on: event.held_on + 1, place: event.place)

    get place_path(event.place)

    assert_response :success
    assert_select "a[href=?]", event_path(event), count: 0
    assert_select "a[href=?]", event_path(active), text: active.title
  end
end
