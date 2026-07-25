module ImportXAccount
  class AccountImporter
    Result = Struct.new(:account, :status, :at_name, keyword_init: true)

    def self.call(at_name:)
      new(at_name: at_name).call
    end

    def initialize(at_name:)
      @at_name = normalize_at_name(at_name)
    end

    def call
      raise ArgumentError, "at_name is blank" if @at_name.blank?

      if XAccount.exists?(at_name: @at_name)
        return Result.new(
          account: XAccount.find_by!(at_name: @at_name),
          status: :skipped,
          at_name: @at_name
        )
      end

      profile = XApi::UserFetcher.get_by_username(@at_name)

      if XAccount.exists?(x_user_id: profile[:x_user_id]) || XAccount.exists?(at_name: profile[:at_name])
        account = XAccount.find_by(x_user_id: profile[:x_user_id]) || XAccount.find_by!(at_name: profile[:at_name])
        return Result.new(account: account, status: :skipped, at_name: profile[:at_name])
      end

      account = XAccount.create!(
        at_name: profile[:at_name],
        x_user_id: profile[:x_user_id],
        display_name: profile[:display_name],
        profile_image_url: profile[:profile_image_url]
      )

      Result.new(account: account, status: :created, at_name: account.at_name)
    end

    private

    def normalize_at_name(value)
      value.to_s.strip.delete_prefix("@").presence
    end
  end
end
