require "test_helper"

class PlacesControllerTest < ActionDispatch::IntegrationTest
  test "creating a place enqueues a Slack notification job" do
    geocoded = { address: "テスト住所", latitude: 35.0, longitude: 135.0 }

    stub_class_method(PlaceGeocoder, :lookup, ->(*) { geocoded }) do
      assert_enqueued_with(job: NotifySlackOfPlaceJob) do
        post places_path, params: {
          place: { name: "テスト会場", address: "テスト住所" }
        }
      end
    end

    assert_redirected_to Place.find_by!(name: "テスト会場")
  end
end
