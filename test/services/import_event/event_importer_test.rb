require "test_helper"

module ImportEvent
  class EventImporterTest < ActiveSupport::TestCase
    setup do
      @detail_url = "https://japanchess.org/2026/05/summer2026-2/"
      @held_on = Date.new(2026, 6, 27)
      @detail = {
        title: "サマーオープン2026",
        held_on: @held_on,
        detail_url: @detail_url,
        place_name: "きゅりあん（品川区総合区民会館）",
        place_address: "東京都品川区東大井5-18-1"
      }
    end

    test "creates place and event from url" do
      detail_url = @detail_url
      detail = @detail
      html = file_fixture("import_event/detail.html").read
      fetched_url = nil
      extracted_args = nil

      stub_class_method(Client, :get, ->(url) {
        fetched_url = url
        html
      }) do
        stub_class_method(Claude::EventExtractor, :extract, ->(html, url:, existing_place_names:) {
          extracted_args = { html: html, url: url, existing_place_names: existing_place_names }
          detail
        }) do
          stub_class_method(PlaceGeocoder, :lookup, ->(_address) {
            {
              address: "東京都品川区東大井5-18-1",
              latitude: 35.6065,
              longitude: 139.7345
            }
          }) do
            assert_difference("Event.count" => 1, "Place.count" => 1) do
              result = EventImporter.call(url: detail_url)
              assert_equal :created, result.status
              assert result.place_created
              assert_equal "サマーオープン2026", result.event.title
              assert result.event.ai?
              assert result.event.place.ai?
            end
          end
        end
      end

      assert_equal detail_url, fetched_url
      assert_includes extracted_args[:html], "サマーオープン2026"
      assert_equal detail_url, extracted_args[:url]
      assert_includes extracted_args[:existing_place_names], places(:one).name
      assert_includes extracted_args[:existing_place_names], places(:two).name
    end

    test "skips existing event by held_on and url" do
      detail_url = @detail_url
      detail = @detail
      existing = Event.create!(
        title: "既存大会",
        held_on: @held_on,
        url: detail_url,
        place: places(:one)
      )

      stub_class_method(Client, :get, ->(_url) { "<html></html>" }) do
        stub_class_method(Claude::EventExtractor, :extract, ->(_html, url:, existing_place_names:) { detail }) do
          assert_no_difference("Event.count") do
            result = EventImporter.call(url: detail_url)
            assert_equal :skipped, result.status
            assert_equal existing, result.event
          end
        end
      end
    end

    test "reuses existing place by name" do
      detail_url = @detail_url
      detail = @detail
      place = Place.create!(
        name: "きゅりあん（品川区総合区民会館）",
        address: "既存の住所",
        latitude: 35.6,
        longitude: 139.7
      )

      stub_class_method(Client, :get, ->(_url) { "<html></html>" }) do
        stub_class_method(Claude::EventExtractor, :extract, ->(_html, url:, existing_place_names:) { detail }) do
          assert_no_difference("Place.count") do
            result = EventImporter.call(url: detail_url)
            assert_equal :created, result.status
            refute result.place_created
            assert_equal place, result.event.place
            assert result.event.ai?
            assert result.event.place.human?
          end
        end
      end
    end

    test "reuses existing place without inferring address when place address is missing" do
      detail_url = @detail_url
      detail = @detail.merge(place_address: nil)
      place = Place.create!(
        name: "きゅりあん（品川区総合区民会館）",
        address: "既存の住所",
        latitude: 35.6,
        longitude: 139.7
      )
      infer_called = false

      stub_class_method(Client, :get, ->(_url) { "<html></html>" }) do
        stub_class_method(Claude::EventExtractor, :extract, ->(_html, url:, existing_place_names:) { detail }) do
          stub_class_method(Claude::AddressInferrer, :infer, ->(place_name:) {
            infer_called = true
            "東京都品川区東大井5-18-1"
          }) do
            assert_no_difference("Place.count") do
              result = EventImporter.call(url: detail_url)
              assert_equal :created, result.status
              refute result.place_created
              assert_equal place, result.event.place
            end
          end
        end
      end

      refute infer_called
    end

    test "reuses existing place by coordinates" do
      detail_url = @detail_url
      detail = @detail.merge(
        place_name: "別名の会場",
        place_address: "別の住所表記"
      )
      place = Place.create!(
        name: "きゅりあん（品川区総合区民会館）",
        address: "東京都品川区東大井5-18-1",
        latitude: 35.6065,
        longitude: 139.7345
      )

      stub_class_method(Client, :get, ->(_url) { "<html></html>" }) do
        stub_class_method(Claude::EventExtractor, :extract, ->(_html, url:, existing_place_names:) { detail }) do
          stub_class_method(PlaceGeocoder, :lookup, ->(_address) {
            {
              address: "東京都品川区東大井5-18-1",
              latitude: 35.6065,
              longitude: 139.7345
            }
          }) do
            assert_no_difference("Place.count") do
              result = EventImporter.call(url: detail_url)
              assert_equal :created, result.status
              refute result.place_created
              assert_equal place, result.event.place
            end
          end
        end
      end
    end

    test "raises when venue name is missing" do
      detail_url = @detail_url
      detail = @detail.merge(place_name: nil, place_address: nil)

      stub_class_method(Client, :get, ->(_url) { "<html></html>" }) do
        stub_class_method(Claude::EventExtractor, :extract, ->(_html, url:, existing_place_names:) { detail }) do
          error = assert_raises(ArgumentError) do
            EventImporter.call(url: detail_url)
          end
          assert_equal "venue name is missing", error.message
        end
      end
    end

    test "infers address with claude when place address is missing" do
      detail_url = @detail_url
      detail = @detail.merge(place_address: nil)
      inferred_place_name = nil
      geocoded_address = nil

      stub_class_method(Client, :get, ->(_url) { "<html></html>" }) do
        stub_class_method(Claude::EventExtractor, :extract, ->(_html, url:, existing_place_names:) { detail }) do
          stub_class_method(Claude::AddressInferrer, :infer, ->(place_name:) {
            inferred_place_name = place_name
            "東京都品川区東大井5-18-1"
          }) do
            stub_class_method(PlaceGeocoder, :lookup, ->(address) {
              geocoded_address = address
              {
                address: "東京都品川区東大井5-18-1",
                latitude: 35.6065,
                longitude: 139.7345
              }
            }) do
              assert_difference("Event.count" => 1, "Place.count" => 1) do
                result = EventImporter.call(url: detail_url)
                assert_equal :created, result.status
              end
            end
          end
        end
      end

      assert_equal detail[:place_name], inferred_place_name
      assert_equal "東京都品川区東大井5-18-1", geocoded_address
    end
  end
end
