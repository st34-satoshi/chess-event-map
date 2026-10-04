require "test_helper"

class WebsitesAdminControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in admin_users(:one)
  end

  test "registers a website linked to an x account" do
    assert_difference "Website.count", 1 do
      post websites_resource_path, params: {
        website: { name: "新しいクラブ", url: "https://new-club.example.com/", x_account_id: x_accounts(:two).id, active: "1" }
      }
    end

    website = Website.find_by!(url: "https://new-club.example.com/")
    assert_redirected_to website_resource_path(website)
    assert_equal x_accounts(:two), website.x_account
  end

  test "lists websites with their x account" do
    get websites_resource_path

    assert_response :success
    assert_select "td.col-name", text: websites(:one).name
    assert_select "td a", text: "@#{x_accounts(:one).at_name}"
  end

  test "new form preselects the x account" do
    get new_website_resource_path(website: { x_account_id: x_accounts(:one).id })

    assert_response :success
    assert_select "select[name='website[x_account_id]'] option[selected][value='#{x_accounts(:one).id}']"
  end

  test "x account page shows linked websites" do
    get x_account_resource_path(x_accounts(:one))

    assert_response :success
    assert_select ".panel", text: /同じクラブのWebサイト/
    assert_select "a", text: websites(:one).name
  end

  private

  def admin_path(name, *args, **params)
    public_send(:"#{ActiveAdmin.application.default_namespace}_#{name}_path", *args, **params)
  end

  def websites_resource_path = admin_path(:websites)
  def new_website_resource_path(**params) = public_send(:"new_#{ActiveAdmin.application.default_namespace}_website_path", **params)
  def website_resource_path(website) = admin_path(:website, website)
  def x_account_resource_path(account) = admin_path(:x_account, account)
end
