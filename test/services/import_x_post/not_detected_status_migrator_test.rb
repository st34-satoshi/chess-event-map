require "test_helper"

class ImportXPost::NotDetectedStatusMigratorTest < ActiveSupport::TestCase
  setup do
    @account = XAccount.create!(
      at_name: "migrator_user",
      x_user_id: "9201",
      display_name: "Migrator User"
    )
  end

  test "migrates not_detected posts to no_event and leaves other statuses untouched" do
    not_detected = create_post!(x_post_id: "m1", status: :not_detected)
    detected = create_post!(x_post_id: "m2", status: :detected)

    assert_equal 1, ImportXPost::NotDetectedStatusMigrator.call

    assert not_detected.reload.no_event?
    assert detected.reload.detected?
  end

  private

  def create_post!(x_post_id:, status:)
    XPost.create!(
      x_account: @account,
      x_post_id: x_post_id,
      text: "post #{x_post_id}",
      posted_at: Time.current,
      event_detection_status: status
    )
  end
end
