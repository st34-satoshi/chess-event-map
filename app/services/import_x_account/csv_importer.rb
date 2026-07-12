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

        if XAccount.exists?(at_name: at_name)
          skipped << at_name
          next
        end

        profile = XApi::Client.get_user_by_username(at_name)

        if XAccount.exists?(x_user_id: profile[:x_user_id]) || XAccount.exists?(at_name: profile[:at_name])
          skipped << profile[:at_name]
          next
        end

        created << XAccount.create!(
          at_name: profile[:at_name],
          x_user_id: profile[:x_user_id],
          display_name: profile[:display_name],
          profile_image_url: profile[:profile_image_url]
        )
      end

      Result.new(created: created, skipped: skipped)
    end

    private

    def normalize_at_name(value)
      value.to_s.strip.delete_prefix("@").presence
    end
  end
end
