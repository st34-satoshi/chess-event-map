require "application_system_test_case"
require_relative "../support/x_posting_helper"

class XPostingTest < ApplicationSystemTestCase
  include Warden::Test::Helpers
  include XPostingHelper

  teardown { Warden.test_reset! }

  test "admin explicitly selects a connected account and stops publishing" do
    account = create_posting_account
    create_posting_account(id: "200", username: "unexpected")
    login_as admin_users(:one), scope: :admin_user
    visit posting_path
    assert_text "未選択（投稿停止中）"
    select "@#{account.username} / #{account.name} (X ID: #{account.x_user_id})", from: "投稿に使用するXアカウント"
    click_button "投稿先を保存"
    assert_text "投稿先を @announcer に変更しました。"
    assert_equal account, XPostingSetting.current.x_posting_account
    select "未選択（投稿停止）", from: "投稿に使用するXアカウント"
    click_button "投稿先を保存"
    assert_text "X投稿を停止しました。"
    assert_nil XPostingSetting.current.x_posting_account
  end
end
