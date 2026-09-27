require "test_helper"

class EventsAdminControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in admin_users(:one)
  end

  test "updates x_post_url from the admin form" do
    event = events(:one)
    x_post_url = "https://x.com/example/status/123"

    patch event_resource_path(event), params: {
      event: {
        title: event.title,
        held_on: event.held_on,
        url: event.url,
        x_post_url: x_post_url,
        place_id: event.place_id
      }
    }

    assert_redirected_to event_resource_path(event)
    assert_equal x_post_url, event.reload.x_post_url
  end

  test "filters events by whether x_post_url is present" do
    with_url = events(:one)
    without_url = events(:two)
    with_url.update!(x_post_url: "https://x.com/example/status/123")

    [ nil, "" ].each do |blank_url|
      without_url.update!(x_post_url: blank_url)

      get events_resource_path, params: { q: { x_post_url_present: "true" } }

      assert_response :success
      assert_select "#index_table_events td.col-title", text: with_url.title
      assert_select "#index_table_events td.col-title", text: without_url.title, count: 0
      assert_select "select[name='q[x_post_url_present]'] option", text: "空"
      assert_select "select[name='q[x_post_url_present]'] option", text: "空でない"
      assert_select "input[name='q[title_cont]']"

      get events_resource_path, params: { q: { x_post_url_present: "false" } }

      assert_response :success
      assert_select "#index_table_events td.col-title", text: without_url.title
      assert_select "#index_table_events td.col-title", text: with_url.title, count: 0

      get events_resource_path, params: { q: { x_post_url_present: "" } }

      assert_response :success
      assert_select "#index_table_events td.col-title", text: with_url.title
      assert_select "#index_table_events td.col-title", text: without_url.title
    end
  end

  private

  def events_resource_path
    Rails.application.routes.url_helpers.public_send(
      :"#{ActiveAdmin.application.default_namespace}_events_path"
    )
  end

  def event_resource_path(event)
    Rails.application.routes.url_helpers.public_send(
      :"#{ActiveAdmin.application.default_namespace}_event_path",
      event
    )
  end
end
