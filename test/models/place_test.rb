require "test_helper"

class PlaceTest < ActiveSupport::TestCase
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
end
