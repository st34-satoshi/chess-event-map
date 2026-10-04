require "test_helper"

class WebsiteTest < ActiveSupport::TestCase
  test "can be linked to an x account" do
    assert_equal x_accounts(:one), websites(:one).x_account
    assert_includes x_accounts(:one).websites, websites(:one)
  end

  test "x account is optional" do
    website = Website.new(name: "クラブ", url: "https://club.example.com/")

    assert website.valid?
  end

  test "requires an http url" do
    website = Website.new(name: "クラブ", url: "ftp://club.example.com/")

    assert_not website.valid?
    assert website.errors.of_kind?(:url, :invalid)
  end

  test "requires a unique url" do
    website = Website.new(name: "別名", url: websites(:one).url)

    assert_not website.valid?
    assert website.errors.of_kind?(:url, :taken)
  end

  test "unlinks websites when the x account is destroyed" do
    website = websites(:one)
    x_accounts(:one).destroy!

    assert_nil website.reload.x_account_id
  end
end
