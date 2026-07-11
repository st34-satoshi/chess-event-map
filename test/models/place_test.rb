require "test_helper"

class PlaceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "creating a place enqueues a Slack notification job" do
    assert_enqueued_with(job: NotifySlackOfPlaceJob) do
      Place.create!(name: "テスト会場", address: "テスト住所", latitude: 35.0, longitude: 135.0)
    end
  end
end
