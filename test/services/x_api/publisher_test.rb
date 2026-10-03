require "test_helper"
require_relative "../../support/x_posting_helper"

class XApi::PublisherTest < ActiveSupport::TestCase
  include XPostingHelper

  setup do
    @account = create_posting_account
    @arguments = { event_uid: events(:one).public_uid, text: "チェス大会のお知らせ https://example.com/event", request_id: "request-123" }
  end

  test "fails closed when no account is selected" do
    assert_raises(XApi::Error) { XApi::Publisher.call(**@arguments) }
    assert_equal "failed", XPublication.last.status
    assert_nil XPublication.last.x_post_id
  end

  test "publishes only through selected user, records it and reuses successful result" do
    create_posting_account(id: "999", username: "unexpected")
    XPostingSetting.current.update!(x_posting_account: @account)
    request = stub_request(:post, "https://api.x.com/2/tweets")
      .with(headers: { "Authorization" => "Bearer user-access-secret" }, body: { text: @arguments[:text] }.to_json)
      .to_return(status: 201, body: { data: { id: "123456" } }.to_json)
    publication = XApi::Publisher.call(**@arguments)
    assert_equal @account, publication.x_posting_account
    assert_equal "published", publication.status
    assert_equal "https://x.com/i/web/status/123456", publication.post_url
    XPostingSetting.current.update!(x_posting_account: nil)
    assert_equal publication.id, XApi::Publisher.call(**@arguments).id
    assert_raises(XApi::Error) { XApi::Publisher.call(**@arguments.merge(text: "different")) }
    assert_raises(XApi::Error) { XApi::Publisher.call(**@arguments.merge(event_uid: events(:two).public_uid)) }
    assert_requested request, times: 1
  end

  test "refreshes expired user token and retains rotation even if publishing fails" do
    XPostingSetting.current.update!(x_posting_account: @account)
    @account.update!(expires_at: 1.minute.ago)
    with_x_credentials do
      refresh = stub_request(:post, "https://api.x.com/2/oauth2/token")
        .with(body: { grant_type: "refresh_token", refresh_token: "user-refresh-secret" })
        .to_return(status: 200, body: token_response.merge("access_token" => "new-access", "refresh_token" => "new-refresh").to_json)
      post_request = stub_request(:post, "https://api.x.com/2/tweets")
        .with(headers: { "Authorization" => "Bearer new-access" }).to_return(status: 403, body: "private detail")
      error = assert_raises(XApi::Error) { XApi::Publisher.call(**@arguments) }
      assert_not_includes error.message, "private detail"
      assert_equal "new-refresh", @account.reload.refresh_token
      assert_equal "new-access", @account.access_token
      assert_operator @account.expires_at, :>, Time.current
      assert_equal "failed", XPublication.last.status
      assert_raises(XApi::Error) { XApi::Publisher.call(**@arguments) }
      assert_requested refresh, times: 1
      assert_requested post_request, times: 1
    end
  end

  test "timeouts and pending reservations never automatically repost" do
    XPostingSetting.current.update!(x_posting_account: @account)
    request = stub_request(:post, "https://api.x.com/2/tweets").to_timeout
    assert_raises(XApi::Error) { XApi::Publisher.call(**@arguments) }
    assert_raises(XApi::Error) { XApi::Publisher.call(**@arguments) }
    assert_requested request, times: 1
    XPublication.last.update!(status: "pending")
    assert_raises(XApi::Error) { XApi::Publisher.call(**@arguments) }
    assert_requested request, times: 1
  end

  test "refresh failures do not fall back to another user or app token" do
    XPostingSetting.current.update!(x_posting_account: @account)
    @account.update!(expires_at: 1.minute.ago)
    with_x_credentials do
      stub_request(:post, "https://api.x.com/2/oauth2/token").to_return(status: 401)
      assert_raises(XApi::Error) { XApi::Publisher.call(**@arguments) }
      assert_not_requested :post, "https://api.x.com/2/tweets"
    end
  end

  test "invalid event or input does not publish" do
    XPostingSetting.current.update!(x_posting_account: @account)
    assert_raises(ActiveRecord::RecordNotFound) { XApi::Publisher.call(**@arguments.merge(event_uid: "missing")) }
    assert_raises(ActiveRecord::RecordInvalid) { XApi::Publisher.call(**@arguments.merge(text: "")) }
    assert_raises(ActiveRecord::RecordInvalid) { XApi::Publisher.call(**@arguments.merge(request_id: "x" * 101)) }
    assert_empty XPublication.all
  end
  test "a retry during an in-flight request does not post again" do
    XPostingSetting.current.update!(x_posting_account: @account)
    request = stub_request(:post, "https://api.x.com/2/tweets").to_return do
      error = assert_raises(XApi::Error) { XApi::Publisher.call(**@arguments) }
      assert_includes error.message, "pending"
      { status: 201, body: { data: { id: "888" } }.to_json }
    end
    assert_equal "published", XApi::Publisher.call(**@arguments).status
    assert_requested request, times: 1
  end

  test "an event with publication history cannot be deleted" do
    event = events(:one)
    XPublication.create!(event: event, text: "History", request_id: "history")
    assert_not event.destroy
    assert event.errors.any?
    assert event.persisted?
  end

  test "oversized multibyte text is rejected before insertion" do
    assert_raises(ActiveRecord::RecordInvalid) { XApi::Publisher.call(**@arguments.merge(text: "あ" * 25_000)) }
    assert_empty XPublication.all
  end
end
