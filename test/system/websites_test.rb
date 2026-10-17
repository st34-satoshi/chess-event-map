require "application_system_test_case"

class WebsitesTest < ApplicationSystemTestCase
  include Warden::Test::Helpers

  teardown { Warden.test_reset! }

  test "searches x accounts and saves the selected account" do
    x_accounts(:two).update!(display_name: "大阪チェスクラブ")
    login_as admin_users(:one), scope: :admin_user
    visit public_send(:"new_#{ActiveAdmin.application.default_namespace}_website_path")

    fill_in "Xアカウントを検索", with: "CHESS_TOKYO"
    assert_selector "#website_x_account_id option", text: "Chess Tokyo"
    assert_no_selector "#website_x_account_id option", text: "大阪チェスクラブ"

    fill_in "Xアカウントを検索", with: "大阪"
    assert_no_selector "#website_x_account_id option", text: "Chess Tokyo"
    select "@chess_osaka (大阪チェスクラブ)", from: "同じクラブのXアカウント"
    fill_in "Xアカウントを検索", with: "該当なし"
    assert_select_value x_accounts(:two).id

    fill_in "Xアカウントを検索", with: ""
    assert_selector "#website_x_account_id option", text: "Chess Tokyo"
    fill_in "名前", with: "検索テストクラブ"
    fill_in "URL", with: "https://search-club.example.com/"
    click_button "Create Website"
    assert_text "検索テストクラブ"
    assert_equal x_accounts(:two), Website.find_by!(name: "検索テストクラブ").x_account
  end

  test "keeps a preselected account and allows clearing it" do
    login_as admin_users(:one), scope: :admin_user
    visit public_send(:"edit_#{ActiveAdmin.application.default_namespace}_website_path", websites(:one))

    fill_in "Xアカウントを検索", with: "osaka"
    assert_select_value x_accounts(:one).id
    select "なし", from: "同じクラブのXアカウント"
    click_button "Update Website"
    assert_text websites(:one).name
    assert_nil websites(:one).reload.x_account
  end

  private

  def assert_select_value(value)
    assert_equal value.to_s, find("#website_x_account_id").value
  end
end
