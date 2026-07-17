require "test_helper"

class ImportXPost::EventDetectionBatchTest < ActiveSupport::TestCase
  setup do
    XPost.pending.update_all(event_detection_status: XPost.event_detection_statuses[:no_event])

    @account = XAccount.create!(
      at_name: "batch_user",
      x_user_id: "9001",
      display_name: "Batch User"
    )
  end

  test "notifies Slack before and after processing pending posts" do
    pending_post = create_pending_post!(x_post_id: "p1", text: "chess event")
    create_pending_post!(x_post_id: "p2", text: "another post")

    messages = []
    statuses = []

    stub_class_method(SlackNotifier, :notify, ->(text) { messages << text }) do
      stub_class_method(ImportXPost::EventDetector, :call, lambda { |x_post|
        status = x_post.x_post_id == "p1" ? :detected : :no_event
        x_post.update!(event_detection_status: status)
        ImportXPost::EventDetector::Result.new(status: status, x_post: x_post)
      }) do
        result = ImportXPost::EventDetectionBatch.call do |detection|
          statuses << detection.status
        end

        assert_equal 2, result.pending_count
        assert_equal 1, result.counts[:detected]
        assert_equal 1, result.counts[:no_event]
      end
    end

    assert_equal %i[detected no_event], statuses
    assert_equal 2, messages.size
    assert_includes messages.first, "対象: 2件"
    assert_includes messages.first, "開始します"
    assert_includes messages.last, "完了しました"
    assert_includes messages.last, "detected: 1"
    assert_includes messages.last, "no_event: 1"
    assert_includes messages.last, "already_exists: 0"
    assert_includes messages.last, "save_failed: 0"
    assert_equal "detected", pending_post.reload.event_detection_status
  end

  test "notifies Slack even when there are no pending posts" do
    messages = []

    stub_class_method(SlackNotifier, :notify, ->(text) { messages << text }) do
      stub_class_method(ImportXPost::EventDetector, :call, ->(*) { flunk "should not detect" }) do
        result = ImportXPost::EventDetectionBatch.call

        assert_equal 0, result.pending_count
        assert_equal 0, result.counts.values.sum
      end
    end

    assert_equal 2, messages.size
    assert_includes messages.first, "対象: 0件"
    assert_includes messages.last, "対象: 0件"
  end

  test "includes save_failed error details in the finish Slack notification" do
    create_pending_post!(x_post_id: "ok", text: "ok")
    failed = create_pending_post!(x_post_id: "ng", text: "ng")

    messages = []

    stub_class_method(SlackNotifier, :notify, ->(text) { messages << text }) do
      stub_class_method(ImportXPost::EventDetector, :call, lambda { |x_post|
        if x_post.x_post_id == "ng"
          x_post.save_failed!
          ImportXPost::EventDetector::Result.new(
            status: :save_failed,
            x_post: x_post,
            error: "Validation failed: 会場の緯度経度は日本国内である必要があります"
          )
        else
          x_post.detected!
          ImportXPost::EventDetector::Result.new(status: :detected, x_post: x_post)
        end
      }) do
        result = ImportXPost::EventDetectionBatch.call

        assert_equal 1, result.counts[:detected]
        assert_equal 1, result.counts[:save_failed]
        assert_equal 1, result.errors.size
      end
    end

    assert_equal 2, messages.size
    assert_includes messages.last, "失敗詳細:"
    assert_includes messages.last, failed.public_uid
    assert_includes messages.last, "@batch_user"
    assert_includes messages.last, "会場の緯度経度は日本国内である必要があります"
  end

  test "skips pending posts older than one month" do
    recent = create_pending_post!(x_post_id: "recent", text: "recent", posted_at: 1.day.ago)
    create_pending_post!(x_post_id: "old", text: "old", posted_at: 2.months.ago)

    processed_ids = []

    stub_class_method(SlackNotifier, :notify, ->(*) { }) do
      stub_class_method(ImportXPost::EventDetector, :call, lambda { |x_post|
        processed_ids << x_post.x_post_id
        x_post.no_event!
        ImportXPost::EventDetector::Result.new(status: :no_event, x_post: x_post)
      }) do
        result = ImportXPost::EventDetectionBatch.call

        assert_equal 1, result.pending_count
        assert_equal 1, result.counts[:no_event]
      end
    end

    assert_equal [ "recent" ], processed_ids
    assert recent.reload.no_event?
    assert XPost.find_by!(x_post_id: "old").pending?
  end

  private

  def create_pending_post!(x_post_id:, text:, posted_at: Time.current)
    XPost.create!(
      x_account: @account,
      x_post_id: x_post_id,
      text: text,
      posted_at: posted_at,
      event_detection_status: :pending
    )
  end
end
