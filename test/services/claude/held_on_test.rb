require "test_helper"

module Claude
  class HeldOnTest < ActiveSupport::TestCase
    test "parses iso8601 date within six months" do
      travel_to Date.new(2026, 7, 12) do
        assert_equal Date.new(2026, 7, 5), HeldOn.parse("2026-07-05")
        assert_equal Date.new(2027, 1, 12), HeldOn.parse("2027-01-12")
        assert_equal Date.new(2026, 1, 12), HeldOn.parse("2026-01-12")
      end
    end

    test "returns nil for blank or invalid values" do
      assert_nil HeldOn.parse(nil)
      assert_nil HeldOn.parse("")
      assert_nil HeldOn.parse("not-a-date")
    end

    test "raises when date is more than six months away" do
      travel_to Date.new(2026, 7, 12) do
        error = assert_raises(Error) { HeldOn.parse("2027-01-13") }
        assert_match(/more than 6 months/, error.message)

        error = assert_raises(Error) { HeldOn.parse("2026-01-11") }
        assert_match(/more than 6 months/, error.message)
      end
    end
  end
end
