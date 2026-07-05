require "test_helper"

class RequestsControllerTest < ActionDispatch::IntegrationTest
  test "creating a request enqueues a Slack notification job" do
    place = Place.create!(name: "テスト会場", address: "テスト住所", latitude: 35.0, longitude: 135.0)

    assert_enqueued_with(job: NotifySlackOfRequestJob) do
      post requests_path, params: {
        correctable_type: "Place",
        correctable_public_uid: place.public_uid,
        request: { comment: "住所が間違っています" }
      }
    end

    assert_redirected_to place
  end
end
