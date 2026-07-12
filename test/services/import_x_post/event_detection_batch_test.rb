require "test_helper"

class ImportXPost::EventDetectionBatchTest < ActiveSupport::TestCase
  setup do
    XPost.pending.update_all(event_detection_status: XPost.event_detection_statuses[:not_detected])

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
        status = x_post.x_post_id == "p1" ? :detected : :not_detected
        x_post.update!(event_detection_status: status)
        ImportXPost::EventDetector::Result.new(status: status, x_post: x_post)
      }) do
        result = ImportXPost::EventDetectionBatch.call do |detection|
          statuses << detection.status
        end

        assert_equal 2, result.pending_count
        assert_equal 1, result.counts[:detected]
        assert_equal 1, result.counts[:not_detected]
      end
    end

    assert_equal %i[detected not_detected], statuses
    assert_equal 2, messages.size
    assert_includes messages.first, "対象: 2件"
    assert_includes messages.first, "開始します"
    assert_includes messages.last, "完了しました"
    assert_includes messages.last, "detected: 1"
    assert_includes messages.last, "not_detected: 1"
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

  private

  def create_pending_post!(x_post_id:, text:)
    XPost.create!(
      x_account: @account,
      x_post_id: x_post_id,
      text: text,
      posted_at: Time.current,
      event_detection_status: :pending
    )
  end
end
