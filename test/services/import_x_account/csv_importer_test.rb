require "test_helper"

module ImportXAccount
  class CsvImporterTest < ActiveSupport::TestCase
    setup do
      @profiles = {
        "JapanChessFed" => {
          x_user_id: "111",
          at_name: "JapanChessFed",
          display_name: "日本チェス連盟",
          profile_image_url: "https://example.com/jcf.png"
        },
        "nagoyachessclub" => {
          x_user_id: "222",
          at_name: "nagoyachessclub",
          display_name: "名古屋チェスクラブ",
          profile_image_url: "https://example.com/ncc.png"
        }
      }
    end

    test "fetches profile from X API and creates accounts" do
      path = write_csv(<<~CSV)
        at_name
        @JapanChessFed
        nagoyachessclub
      CSV

      stub_user_lookup do
        assert_difference("XAccount.count", 2) do
          result = CsvImporter.call(path: path)

          assert_equal 2, result.created.size
          assert_empty result.skipped

          account = result.created.find { |a| a.at_name == "JapanChessFed" }
          assert_equal "111", account.x_user_id
          assert_equal "日本チェス連盟", account.display_name
          assert_equal "https://example.com/jcf.png", account.profile_image_url
        end
      end
    end

    test "skips already registered at_name without calling API" do
      XAccount.create!(
        at_name: "JapanChessFed",
        x_user_id: "111",
        display_name: "日本チェス連盟"
      )
      path = write_csv(<<~CSV)
        at_name
        @JapanChessFed
        @nagoyachessclub
      CSV

      looked_up = []
      stub_user_lookup(looked_up) do
        assert_difference("XAccount.count", 1) do
          result = CsvImporter.call(path: path)

          assert_equal [ "nagoyachessclub" ], result.created.map(&:at_name)
          assert_equal [ "JapanChessFed" ], result.skipped
          assert_equal [ "nagoyachessclub" ], looked_up
        end
      end
    end

    test "ignores blank at_name rows" do
      path = write_csv(<<~CSV)
        at_name
        @JapanChessFed

        @
      CSV

      stub_user_lookup do
        assert_difference("XAccount.count", 1) do
          result = CsvImporter.call(path: path)

          assert_equal [ "JapanChessFed" ], result.created.map(&:at_name)
          assert_empty result.skipped
        end
      end
    end

    private

    def stub_user_lookup(looked_up = nil, &block)
      profiles = @profiles
      stub_class_method(XApi::UserFetcher, :get_by_username, ->(username) {
        looked_up << username if looked_up
        profiles.fetch(username)
      }, &block)
    end

    def write_csv(content)
      file = Tempfile.new([ "x_accounts", ".csv" ])
      file.write(content)
      file.close
      file.path
    end
  end
end
