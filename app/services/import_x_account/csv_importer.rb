require "csv"

module ImportXAccount
  class CsvImporter
    DEFAULT_PATH = Rails.root.join("db/data/x_accounts.csv")

    Result = Struct.new(:created, :skipped, keyword_init: true)

    def self.call(path: DEFAULT_PATH)
      new(path: path).call
    end

    def initialize(path:)
      @path = path
    end

    def call
      created = []
      skipped = []

      CSV.foreach(@path, headers: true) do |row|
        at_name = normalize_at_name(row["at_name"])
        next if at_name.blank?

        result = AccountImporter.call(at_name: at_name)

        case result.status
        when :created
          created << result.account
        when :skipped
          skipped << result.at_name
        end
      end

      Result.new(created: created, skipped: skipped)
    end

    private

    def normalize_at_name(value)
      value.to_s.strip.delete_prefix("@").presence
    end
  end
end
