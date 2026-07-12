require "test_helper"

module ImportXPost
  class EventDetectorTest < ActiveSupport::TestCase
    setup do
      @account = x_accounts(:one)
      @post = XPost.create!(
        x_account: @account,
        x_post_id: "9001",
        text: "来週の例会のお知らせ",
        posted_at: Time.current,
        url: "https://x.com/chess_tokyo/status/9001",
        event_detection_status: :pending
      )
    end

    test "marks not_detected when post has no event info" do
      stub_class_method(Claude::XPostEventAnalyzer, :analyze, ->(_text, existing_place_names: []) {
        { has_event: false }
      }) do
        result = EventDetector.call(@post)

        assert_equal :not_detected, result.status
        assert @post.reload.not_detected?
      end
    end

    test "passes existing place names to analyzer" do
      analyzed_args = nil

      stub_class_method(Claude::XPostEventAnalyzer, :analyze, ->(text, existing_place_names: []) {
        analyzed_args = { text: text, existing_place_names: existing_place_names }
        { has_event: false }
      }) do
        EventDetector.call(@post)
      end

      assert_equal @post.text, analyzed_args[:text]
      assert_includes analyzed_args[:existing_place_names], places(:one).name
      assert_includes analyzed_args[:existing_place_names], places(:two).name
    end

    test "imports from detail url and marks detected" do
      event = events(:one)
      imported_url = nil

      stub_class_method(Claude::XPostEventAnalyzer, :analyze, ->(_text, existing_place_names: []) {
        {
          has_event: true,
          title: "例会",
          held_on: Date.new(2026, 7, 5),
          place_name: "会場",
          place_address: nil,
          detail_url: "https://example.com/event"
        }
      }) do
        stub_class_method(ImportEvent::EventImporter, :call, ->(url:) {
          imported_url = url
          ImportEvent::EventImporter::Result.new(status: :created, event: event, place_created: true)
        }) do
          result = EventDetector.call(@post)

          assert_equal :detected, result.status
          assert @post.reload.detected?
          assert_equal event, result.event
        end
      end

      assert_equal "https://example.com/event", imported_url
    end

    test "marks already_exists when url import is skipped" do
      event = events(:one)

      stub_class_method(Claude::XPostEventAnalyzer, :analyze, ->(_text, existing_place_names: []) {
        {
          has_event: true,
          title: "例会",
          held_on: Date.new(2026, 7, 5),
          place_name: "会場",
          place_address: nil,
          detail_url: "https://example.com/event"
        }
      }) do
        stub_class_method(ImportEvent::EventImporter, :call, ->(url:) {
          ImportEvent::EventImporter::Result.new(status: :skipped, event: event, place_created: false)
        }) do
          result = EventDetector.call(@post)

          assert_equal :already_exists, result.status
          assert @post.reload.already_exists?
        end
      end
    end

    test "creates event from analysis without detail url" do
      place = places(:one)

      stub_class_method(Claude::XPostEventAnalyzer, :analyze, ->(_text, existing_place_names: []) {
        {
          has_event: true,
          title: "名古屋例会",
          held_on: Date.new(2026, 8, 1),
          place_name: place.name,
          place_address: place.address,
          detail_url: nil
        }
      }) do
        assert_difference("Event.count", 1) do
          result = EventDetector.call(@post)

          assert_equal :detected, result.status
          assert @post.reload.detected?
          assert_equal "名古屋例会", result.event.title
          assert_equal place, result.event.place
          assert_equal @post.url, result.event.url
        end
      end
    end

    test "marks already_exists when held_on and place already exist" do
      existing = events(:one)

      stub_class_method(Claude::XPostEventAnalyzer, :analyze, ->(_text, existing_place_names: []) {
        {
          has_event: true,
          title: "別タイトル",
          held_on: existing.held_on,
          place_name: existing.place.name,
          place_address: existing.place.address,
          detail_url: nil
        }
      }) do
        assert_no_difference("Event.count") do
          result = EventDetector.call(@post)

          assert_equal :already_exists, result.status
          assert @post.reload.already_exists?
          assert_equal existing, result.event
        end
      end
    end

    test "marks save_failed when required fields are incomplete" do
      stub_class_method(Claude::XPostEventAnalyzer, :analyze, ->(_text, existing_place_names: []) {
        {
          has_event: true,
          title: nil,
          held_on: Date.new(2026, 8, 1),
          place_name: nil,
          place_address: nil,
          detail_url: nil
        }
      }) do
        result = EventDetector.call(@post)

        assert_equal :save_failed, result.status
        assert @post.reload.save_failed?
        assert_includes result.error, "event fields are incomplete"
      end
    end

    test "includes error message when geocoding address cannot be determined" do
      stub_class_method(Claude::XPostEventAnalyzer, :analyze, ->(_text, existing_place_names: []) {
        {
          has_event: true,
          title: "例会",
          held_on: Date.new(2026, 8, 1),
          place_name: "Unknown Venue",
          place_address: nil,
          detail_url: nil
        }
      }) do
        stub_class_method(Claude::AddressInferrer, :infer, ->(place_name:) { nil }) do
          result = EventDetector.call(@post)

          assert_equal :save_failed, result.status
          assert_includes result.error, "geocodable address could not be determined for Unknown Venue"
        end
      end
    end
  end
end
