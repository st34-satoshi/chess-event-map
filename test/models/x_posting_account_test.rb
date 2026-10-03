require "test_helper"
require_relative "../support/x_posting_helper"

class XPostingAccountTest < ActiveSupport::TestCase
  include XPostingHelper

  test "tokens are encrypted at rest and excluded from inspect and search" do
    account = create_posting_account
    assert_equal "user-access-secret", account.reload.access_token
    assert_equal "user-refresh-secret", account.refresh_token
    assert_not_includes account.access_token_ciphertext, "user-access-secret"
    assert_not_includes account.refresh_token_ciphertext, "user-refresh-secret"
    assert_not_includes account.inspect, account.access_token_ciphertext
    assert_not_includes XPostingAccount.ransackable_attributes, "access_token_ciphertext"
  end

  test "rejects missing scopes and initial refresh token" do
    account = XPostingAccount.new(x_user_id: "123", username: "example", name: "Example")
    assert_raises(XApi::Error) { account.apply_tokens!(token_response.merge("scope" => "tweet.read")) }
    assert_raises(XApi::Error) { account.apply_tokens!(token_response.except("refresh_token")) }
    assert_not account.persisted?
  end
end
