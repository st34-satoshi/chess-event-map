require "test_helper"

class ImportXPost::SaveFailedResetterTest < ActiveSupport::TestCase
  setup do
    @account = XAccount.create!(
      at_name: "reset_user",
      x_user_id: "9101",
      display_name: "Reset User"
    )
  end

  test "resets recent save_failed posts to pending" do
    recent_failed = create_post!(x_post_id: "r1", posted_at: 1.day.ago, status: :save_failed)
    old_failed = create_post!(x_post_id: "r2", posted_at: 2.months.ago, status: :save_failed)
    recent_detected = create_post!(x_post_id: "r3", posted_at: 1.day.ago, status: :detected)

    assert_equal 1, ImportXPost::SaveFailedResetter.call

    assert recent_failed.reload.pending?
    assert old_failed.reload.save_failed?
    assert recent_detected.reload.detected?
  end

  private

  def create_post!(x_post_id:, posted_at:, status:)
    XPost.create!(
      x_account: @account,
      x_post_id: x_post_id,
      text: "post #{x_post_id}",
      posted_at: posted_at,
      event_detection_status: status
    )
  end
end
