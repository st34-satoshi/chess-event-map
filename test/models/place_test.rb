require "test_helper"

class PlaceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "creating a place enqueues a Slack notification job" do
    assert_enqueued_with(job: NotifySlackOfPlaceJob) do
      Place.create!(name: "テスト会場", address: "テスト住所", latitude: 35.0, longitude: 135.0)
    end
  end

  test "allows coordinates within japan" do
    place = Place.new(
      name: "東京会場",
      address: "東京都千代田区丸の内1-1",
      latitude: 35.6295,
      longitude: 139.7764
    )

    assert place.valid?
  end

  test "rejects coordinates outside japan" do
    place = Place.new(
      name: "海外会場",
      address: "海外の住所",
      latitude: 40.7128,
      longitude: -74.0060
    )

    assert_not place.valid?
    assert_includes place.errors[:base], "会場の緯度経度は日本国内である必要があります"
  end

  test "defaults created_by to human" do
    place = Place.new(
      name: "東京会場",
      address: "東京都千代田区丸の内1-1",
      latitude: 35.6295,
      longitude: 139.7764
    )

    assert place.human?
  end
end
