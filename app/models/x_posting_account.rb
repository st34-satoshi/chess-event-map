class XPostingAccount < ApplicationRecord
  has_many :x_publications, dependent: :restrict_with_exception

  validates :x_user_id, :username, :name, :access_token_ciphertext, :refresh_token_ciphertext, :expires_at, presence: true
  validates :x_user_id, uniqueness: true

  self.filter_attributes += %i[access_token_ciphertext refresh_token_ciphertext]

  %i[access_token refresh_token].each do |attribute|
    define_method(attribute) do
      value = public_send("#{attribute}_ciphertext")
      token_encryptor.decrypt_and_verify(value, purpose: attribute.to_s) if value.present?
    end

    define_method("#{attribute}=") do |value|
      public_send("#{attribute}_ciphertext=", token_encryptor.encrypt_and_sign(value, purpose: attribute.to_s))
    end
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[id x_user_id username name expires_at created_at updated_at]
  end

  def apply_tokens!(tokens)
    unless tokens["access_token"].present? && tokens["expires_in"].to_i.positive? &&
        (XApi::UserClient::SCOPES - tokens.fetch("scope", "").split).empty?
      raise XApi::Error, "X did not grant the required posting and offline scopes. Reconnect the account."
    end

    if tokens["refresh_token"].blank? && refresh_token_ciphertext.blank?
      raise XApi::Error, "X did not return a refresh token. Reconnect the account."
    end

    self.access_token = tokens.fetch("access_token")
    self.refresh_token = tokens["refresh_token"] if tokens["refresh_token"].present?
    self.expires_at = Time.current + tokens.fetch("expires_in").to_i.seconds
    save!
  end

  private

  def token_encryptor
    key = Rails.application.key_generator.generate_key("x-posting-tokens-v1", 32)
    ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm")
  end
end
