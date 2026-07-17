require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "index shows all places without date filter" do
    get root_path

    assert_response :success
    assert_includes response.body, places(:one).name
    assert_includes response.body, places(:two).name
  end

  test "index filters places by held_on range" do
    places(:one).events.first.update!(held_on: Date.new(2026, 7, 20))
    places(:two).events.first.update!(held_on: Date.new(2026, 8, 1))

    get root_path, params: { from: "2026-07-15", to: "2026-07-25" }

    assert_response :success
    assert_includes response.body, places(:one).name
    assert_not_includes response.body, places(:two).name
    assert_includes response.body, "1件の会場を表示中"
  end

  test "index filters places with only from date" do
    places(:one).events.first.update!(held_on: Date.new(2026, 7, 10))
    places(:two).events.first.update!(held_on: Date.new(2026, 8, 1))

    get root_path, params: { from: "2026-07-15" }

    assert_response :success
    assert_not_includes response.body, places(:one).name
    assert_includes response.body, places(:two).name
  end

  test "index ignores invalid date params" do
    get root_path, params: { from: "not-a-date", to: "also-bad" }

    assert_response :success
    assert_includes response.body, places(:one).name
    assert_includes response.body, places(:two).name
    assert_not_includes response.body, "件の会場を表示中"
  end
end
