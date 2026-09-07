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

  private

  def event_resource_path(event)
    Rails.application.routes.url_helpers.public_send(
      :"#{ActiveAdmin.application.default_namespace}_event_path",
      event
    )
  end
end
