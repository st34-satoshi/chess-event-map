require "test_helper"

class XPostTest < ActiveSupport::TestCase
  test "defaults event_detection_status to pending" do
    post = XPost.new(
      x_account: x_accounts(:one),
      x_post_id: "3000000001",
      text: "chess event tomorrow",
      posted_at: Time.current
    )

    assert post.pending?
    assert_equal "pending", post.event_detection_status
  end

  test "allows detected and not_detected statuses" do
    post = x_posts(:one)

    post.detected!
    assert post.detected?

    post.not_detected!
    assert post.not_detected?
  end
end
