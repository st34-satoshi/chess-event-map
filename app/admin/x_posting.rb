ActiveAdmin.register_page "X Posting" do
  menu label: "X投稿設定"

  content title: "X投稿設定" do
    render partial: "admin/x_posting", locals: {
      accounts: XPostingAccount.order(:username),
      setting: XPostingSetting.current,
      publications: XPublication.includes(:event, :x_posting_account).order(id: :desc).limit(50)
    }
  end

  page_action :connect, method: :post do
    state = SecureRandom.urlsafe_base64(32)
    verifier = SecureRandom.urlsafe_base64(64)
    url = XApi::UserClient.new.authorization_url(state: state, verifier: verifier)
    session[:x_posting_oauth] = { state: state, verifier: verifier, admin_id: current_admin_user.id, started_at: Time.current.to_i }
    redirect_to url, allow_other_host: true
  rescue XApi::Error => e
    redirect_to({ action: :index }, alert: e.message)
  end

  page_action :callback, method: :get do
    pending = session.delete(:x_posting_oauth)
    valid = pending && pending["admin_id"] == current_admin_user.id &&
      pending["started_at"].to_i > 10.minutes.ago.to_i &&
      params[:state].is_a?(String) && ActiveSupport::SecurityUtils.secure_compare(pending["state"], params[:state])
    if !valid || params[:error].present? || !params[:code].is_a?(String) || params[:code].blank?
      redirect_to({ action: :index }, alert: "X認証がキャンセルされたか期限切れです。接続からやり直してください。")
    else
      client = XApi::UserClient.new
      tokens = client.exchange(code: params[:code], verifier: pending.fetch("verifier"))
      user = client.me(tokens.fetch("access_token"))
      # Share the selection/posting lock so reconnects cannot overwrite a refresh.
      XPostingSetting.current.with_lock do
        account = XPostingAccount.find_or_initialize_by(x_user_id: user.fetch("id"))
        account.assign_attributes(username: user.fetch("username"), name: user.fetch("name"))
        account.apply_tokens!(tokens)
      end
      redirect_to({ action: :index }, notice: "@#{user.fetch('username')} を認証しました。投稿に使う場合は投稿先として選択してください。")
    end
  rescue XApi::Error, KeyError, ActiveRecord::RecordInvalid
    redirect_to({ action: :index }, alert: "X認証を保存できませんでした。設定と権限を確認し、再接続してください。")
  end

  page_action :select_account, method: :post do
    account = XPostingAccount.find(params[:account_id]) if params[:account_id].present?
    setting = XPostingSetting.current
    setting.with_lock { setting.update!(x_posting_account: account) }
    redirect_to({ action: :index }, notice: account ? "投稿先を @#{account.username} に変更しました。" : "X投稿を停止しました。")
  end
end
