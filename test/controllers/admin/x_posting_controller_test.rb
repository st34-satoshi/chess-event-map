require "test_helper"
require_relative "../../support/x_posting_helper"

class XPostingControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include XPostingHelper

  setup { sign_in admin_users(:one) }

  test "only admins can access settings or start and finish authentication" do
    sign_out admin_users(:one)
    get posting_path
    assert_response :redirect
    post posting_path(:connect)
    assert_response :redirect
    get posting_path(:callback), params: { code: "bad", state: "bad" }
    assert_response :redirect
    post posting_path(:select_account), params: { account_id: "" }
    assert_response :redirect
    assert_empty XPostingAccount.all
  end

  test "selection is explicit and can be disabled without leaking credentials" do
    account = create_posting_account
    other = create_posting_account(id: "200", username: "other")
    assert_nil XPostingSetting.current.x_posting_account
    post posting_path(:select_account), params: { account_id: account.id }
    assert_response :redirect
    assert_equal account, XPostingSetting.current.x_posting_account
    get posting_path
    assert_response :success
    assert_includes response.body, "@announcer"
    assert_includes response.body, "@other"
    assert_not_includes response.body, "user-access-secret"
    assert_not_includes response.body, account.access_token_ciphertext
    post posting_path(:select_account), params: { account_id: other.id }
    assert_equal other, XPostingSetting.current.x_posting_account
    post posting_path(:select_account), params: { account_id: "" }
    assert_nil XPostingSetting.current.x_posting_account
  end

  test "OAuth uses S256, stores actual user identity, and does not change selection" do
    selected = create_posting_account
    XPostingSetting.current.update!(x_posting_account: selected)
    with_x_credentials do
      post posting_path(:connect)
      assert_response :redirect
      authorization = URI(response.location)
      assert_equal "x.com", authorization.host
      query = URI.decode_www_form(authorization.query).to_h
      assert_equal "S256", query["code_challenge_method"]
      assert_equal XApi::UserClient::SCOPES.join(" "), query["scope"]
      token_request = stub_request(:post, "https://api.x.com/2/oauth2/token")
        .with(basic_auth: %w[client-id client-secret]) { |request|
          form = URI.decode_www_form(request.body).to_h
          assert_equal "authorization_code", form["grant_type"]
          assert_equal "authorized-code", form["code"]
          assert_equal query["code_challenge"], Base64.urlsafe_encode64(Digest::SHA256.digest(form["code_verifier"]), padding: false)
        }.to_return(status: 200, body: token_response.to_json)
      stub_request(:get, "https://api.x.com/2/users/me").with(headers: { "Authorization" => "Bearer user-access-secret" })
        .to_return(status: 200, body: { data: { id: "999", username: "separate_account", name: "Separate" } }.to_json)
      get posting_path(:callback), params: { state: query["state"], code: "authorized-code", account_id: selected.id }
      assert_response :redirect
      account = XPostingAccount.find_by!(x_user_id: "999")
      assert_equal "separate_account", account.username
      assert_equal "user-access-secret", account.access_token
      assert_equal selected, XPostingSetting.current.x_posting_account
      assert_not_includes account.access_token_ciphertext, "user-access-secret"
      get posting_path(:callback), params: { state: query["state"], code: "authorized-code" }
      assert_requested token_request, times: 1
    end
  end

  test "invalid, expired, denied and other-admin OAuth callbacks do not exchange tokens" do
    with_x_credentials do
      post posting_path(:connect)
      get posting_path(:callback), params: { state: "wrong", code: "code" }
      assert_includes flash[:alert], "やり直し"
      post posting_path(:connect)
      state = URI.decode_www_form(URI(response.location).query).to_h["state"]
      travel 11.minutes do
        get posting_path(:callback), params: { state: state, code: "code" }
        assert_includes flash[:alert], "やり直し"
      end
      post posting_path(:connect)
      state = URI.decode_www_form(URI(response.location).query).to_h["state"]
      get posting_path(:callback), params: { state: state, error: "access_denied" }
      assert_includes flash[:alert], "やり直し"
      post posting_path(:connect)
      state = URI.decode_www_form(URI(response.location).query).to_h["state"]
      sign_in admin_users(:two)
      get posting_path(:callback), params: { state: state, code: "code" }
      assert_includes flash[:alert], "やり直し"
      assert_empty XPostingAccount.all
    end
  end
  test "selection requires a valid CSRF token and refuses unknown account IDs" do
    account = create_posting_account
    XPostingSetting.current.update!(x_posting_account: account)
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    post posting_path(:select_account), params: { account_id: "" }
    assert_response :unprocessable_entity
    assert_equal account, XPostingSetting.current.x_posting_account
    sign_in admin_users(:one)
    get posting_path
    assert_response :success
    token = Nokogiri::HTML(response.body).at_css("form[action='#{posting_path(:select_account)}'] input[name='authenticity_token']")["value"]
    post posting_path(:select_account), params: { account_id: "999999", authenticity_token: token }
    assert_response :not_found
    assert_equal account, XPostingSetting.current.x_posting_account
  ensure
    ActionController::Base.allow_forgery_protection = original
  end
end
