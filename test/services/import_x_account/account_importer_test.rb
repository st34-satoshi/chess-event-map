require "test_helper"

module ImportXAccount
  class AccountImporterTest < ActiveSupport::TestCase
    setup do
      @profile = {
        x_user_id: "111",
        at_name: "JapanChessFed",
        display_name: "日本チェス連盟",
        profile_image_url: "https://example.com/jcf.png"
      }
    end

    test "fetches profile from X API and creates account" do
      stub_user_lookup do
        assert_difference("XAccount.count", 1) do
          result = AccountImporter.call(at_name: "@JapanChessFed")

          assert_equal :created, result.status
          assert_equal "JapanChessFed", result.at_name
          assert_equal "111", result.account.x_user_id
          assert_equal "日本チェス連盟", result.account.display_name
          assert_equal "https://example.com/jcf.png", result.account.profile_image_url
        end
      end
    end

    test "skips already registered at_name without calling API" do
      existing = XAccount.create!(
        at_name: "JapanChessFed",
        x_user_id: "111",
        display_name: "日本チェス連盟"
      )

      looked_up = []
      stub_user_lookup(looked_up) do
        assert_no_difference("XAccount.count") do
          result = AccountImporter.call(at_name: "JapanChessFed")

          assert_equal :skipped, result.status
          assert_equal existing, result.account
          assert_equal "JapanChessFed", result.at_name
          assert_empty looked_up
        end
      end
    end

    test "skips when x_user_id is already registered under different at_name" do
      existing = XAccount.create!(
        at_name: "OldName",
        x_user_id: "111",
        display_name: "日本チェス連盟"
      )

      stub_user_lookup do
        assert_no_difference("XAccount.count") do
          result = AccountImporter.call(at_name: "JapanChessFed")

          assert_equal :skipped, result.status
          assert_equal existing, result.account
          assert_equal "JapanChessFed", result.at_name
        end
      end
    end

    test "raises when at_name is blank" do
      assert_raises(ArgumentError) do
        AccountImporter.call(at_name: "  @  ")
      end
    end

    private

    def stub_user_lookup(looked_up = nil, &block)
      profile = @profile
      stub_class_method(XApi::UserFetcher, :get_by_username, ->(username) {
        looked_up << username if looked_up
        profile
      }, &block)
    end
  end
end
