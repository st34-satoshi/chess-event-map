module Claude
  module HeldOn
    MAX_MONTHS_FROM_TODAY = 6

    module_function

    def parse(value, reference_date: Date.current)
      return if value.blank?

      date = Date.iso8601(value.to_s)
      assert_within_range!(date, reference_date)
      date
    rescue Date::Error, TypeError
      nil
    end

    def assert_within_range!(date, reference_date = Date.current)
      min = reference_date - MAX_MONTHS_FROM_TODAY.months
      max = reference_date + MAX_MONTHS_FROM_TODAY.months
      return if date.between?(min, max)

      raise Error,
            "held_on #{date} is more than #{MAX_MONTHS_FROM_TODAY} months from #{reference_date}"
    end
  end
end
