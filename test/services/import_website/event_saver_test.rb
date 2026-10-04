require "test_helper"

module ImportWebsite
  class EventSaverTest < ActiveSupport::TestCase
    test "creates an event at an existing place" do
      analysis = { title: "10月例会", held_on: Date.new(2026, 10, 18), place_name: places(:one).name,
                   place_address: nil, detail_url: nil }

      result = EventSaver.call(analysis, fallback_url: "https://club.example.com/")

      assert_equal :created, result.status
      assert_equal places(:one), result.event.place
      assert_equal "https://club.example.com/", result.event.url
      assert result.event.ai?
    end

    test "uses the detail url as the event url" do
      analysis = { title: "10月例会", held_on: Date.new(2026, 10, 18), place_name: places(:one).name,
                   place_address: nil, detail_url: "https://club.example.com/oct" }

      result = EventSaver.call(analysis, fallback_url: "https://club.example.com/")

      assert_equal "https://club.example.com/oct", result.event.url
    end

    test "returns already_exists for the same place and date" do
      existing = events(:one)
      analysis = { title: "別名", held_on: existing.held_on, place_name: existing.place.name,
                   place_address: nil, detail_url: nil }

      assert_no_difference "Event.count" do
        result = EventSaver.call(analysis, fallback_url: "https://club.example.com/")

        assert_equal :already_exists, result.status
        assert_equal existing, result.event
      end
    end

    test "returns already_exists for a known detail url without resolving the place" do
      existing = events(:one)
      analysis = { title: "別名", held_on: existing.held_on, place_name: "未登録の会場",
                   place_address: nil, detail_url: existing.url }

      result = EventSaver.call(analysis, fallback_url: "https://club.example.com/")

      assert_equal :already_exists, result.status
      assert_equal existing, result.event
    end

    test "reads the detail page when the venue is missing" do
      event = events(:one)
      imported_url = nil
      analysis = { title: "10月例会", held_on: Date.new(2026, 10, 18), place_name: nil,
                   place_address: nil, detail_url: "https://club.example.com/oct" }

      stub_class_method(ImportEvent::EventImporter, :call, ->(url:) {
        imported_url = url
        ImportEvent::EventImporter::Result.new(status: :created, event: event, place_created: false)
      }) do
        result = EventSaver.call(analysis, fallback_url: "https://club.example.com/")

        assert_equal :created, result.status
      end

      assert_equal "https://club.example.com/oct", imported_url
    end

    test "raises when the venue cannot be found" do
      analysis = { title: "10月例会", held_on: Date.new(2026, 10, 18), place_name: nil,
                   place_address: nil, detail_url: nil }

      assert_raises(ArgumentError) do
        EventSaver.call(analysis, fallback_url: "https://club.example.com/")
      end
    end
  end
end
