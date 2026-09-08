require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @today = Date.new(2026, 9, 8)
    events(:one).update!(held_on: @today - 1, title: "昨日の大会")
    events(:two).update!(held_on: @today, title: "今日の大会")
    @tomorrow = Event.create!(
      title: "明日の大会",
      held_on: @today + 1,
      url: "https://example.com/tomorrow",
      place: places(:one)
    )
  end

  test "index shows header link to events" do
    travel_to @today do
      get events_path
    end

    assert_response :success
    assert_includes response.body, "イベント一覧"
    assert_includes response.body, events_path
  end

  test "index defaults to events on or after the access date" do
    travel_to @today do
      get events_path
    end

    assert_response :success
    assert_includes response.body, "今日の大会"
    assert_includes response.body, "明日の大会"
    assert_not_includes response.body, "昨日の大会"
    assert_includes response.body, "2件のイベントを表示中"
    assert_includes response.body, "サイトを開く"
  end

  test "index includes events held on the access date" do
    travel_to @today do
      get events_path
    end

    assert_response :success
    assert_includes response.body, events(:two).place.name
    assert_includes response.body, "2026年09月08日"
  end

  test "index filters events by held_on range" do
    travel_to @today do
      get events_path, params: { from: "2026-09-08", to: "2026-09-08" }
    end

    assert_response :success
    assert_includes response.body, "今日の大会"
    assert_not_includes response.body, "昨日の大会"
    assert_not_includes response.body, "明日の大会"
  end

  test "index shows past events when from is blank" do
    travel_to @today do
      get events_path, params: { from: "", to: "" }
    end

    assert_response :success
    assert_includes response.body, "昨日の大会"
    assert_includes response.body, "今日の大会"
    assert_includes response.body, "明日の大会"
  end

  test "index ignores invalid date params" do
    travel_to @today do
      get events_path, params: { from: "not-a-date", to: "also-bad" }
    end

    assert_response :success
    assert_includes response.body, "昨日の大会"
    assert_includes response.body, "今日の大会"
    assert_includes response.body, "明日の大会"
  end

  test "index caps results at 50 and shows a truncation message" do
    place = Place.create!(
      name: "大量会場",
      address: "東京都千代田区1-1-1",
      latitude: 35.0,
      longitude: 139.0
    )
    start_on = @today + 100
    now = Time.current
    Event.insert_all(
      (EventsController::INDEX_LIMIT + 1).times.map do |i|
        {
          title: "大量大会#{format("%02d", i)}",
          held_on: start_on + i,
          place_id: place.id,
          public_uid: format("limituid%04d", i),
          created_at: now,
          updated_at: now
        }
      end
    )

    travel_to @today do
      get events_path, params: {
        from: start_on.iso8601,
        to: (start_on + EventsController::INDEX_LIMIT).iso8601
      }
    end

    assert_response :success
    assert_includes response.body, "50件のイベントを表示中"
    assert_includes response.body, "該当が50件を超えたため"
    assert_includes response.body, "大量大会00"
    assert_includes response.body, "大量大会49"
    assert_not_includes response.body, "大量大会50"
  end
end
