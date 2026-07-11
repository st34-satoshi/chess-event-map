require "test_helper"

module ImportEvent
  class HtmlCleanerTest < ActiveSupport::TestCase
    test "removes navigation scripts and keeps entry content" do
      html = file_fixture("import_event/detail.html").read
      cleaned = HtmlCleaner.clean(html)

      assert_includes cleaned, "サマーオープン2026"
      assert_includes cleaned, "東京都品川区東大井5-18-1"
      refute_includes cleaned, "<script"
      refute_includes cleaned, "navigation"
    end
  end
end
