# Xへのイベント告知

開発者のXアプリに、投稿したい別のXアカウントでOAuth 2.0認可を与えます。
既存の `XAccount` / `x.bearer_token` は取得専用です。投稿用アカウント・トークン・履歴は分離されています。

## サーバー設定

1. X Developer ConsoleでアプリのOAuth 2.0を有効にし、種類を **Web App / Automated App or bot（confidential client）** にします。投稿APIを利用できる権限・利用枠も確認します。
2. Callback URIを `https://chess-event-map.stu345.com/<管理画面のパス>/x_posting/callback` に設定します。管理画面のパスは `active_admin_path` credentials（未設定時 `admin`）。完全一致が必要です。
3. `rails credentials:edit` で以下を追加します。既存の `x.bearer_token` はそのまま残します。

   ```yaml
   x:
     oauth:
       client_id: XのOAuth2クライアントID
       client_secret: XのOAuth2クライアントシークレット
       redirect_uri: https://chess-event-map.stu345.com/manage/x_posting/callback
     mcp_token: 十分に長いランダムな専用シークレット
   ```

   `mcp_token` は例えば `openssl rand -hex 32` で生成します。Xのトークンとは別物で、この値を知るMCPクライアントは投稿を指示できます。チャット本文・Git・共有MCP設定に含めないでください。未設定時はMCPへのアクセスを拒否します。ローテーションはcredentialsの変更とアプリ再起動で行います。
4. デプロイ時に `bin/rails db:migrate` を実行してアプリを再起動します。投稿トークンは `secret_key_base` から導出した鍵で暗号化保存されます。既存の鍵を維持し、変更した場合は全投稿アカウントを再認証してください。

## 投稿アカウントを設定

1. 管理画面の **X投稿設定** → **Xアカウントを接続・再認証** を押します。
2. Xで目的の投稿アカウントにログインして認可します（開発アカウントである必要はありません）。現在Xにログイン中のアカウント名を確認してください。
3. 戻ってきたらアカウント名とX IDを確認し、**投稿に使用するXアカウント** で選択して **投稿先を保存** を押します。

認証しただけでは選択は変わりません。未選択時は投稿できません。管理者ログインのない利用者は認証開始・コールバック・選択操作を使えません。MCPからアカウントを選択・指定することもできません。
**未選択（投稿停止）** を保存すると以降の投稿を停止します。進行中の投稿完了を待って設定が反映されます。X側でアプリ認可を取り消した場合や更新に失敗する場合は再認証します。

## Claude Codeなどから接続

MCPエンドポイント: `https://chess-event-map.stu345.com/mcp`

Streamable HTTPとAuthorizationヘッダーに対応するクライアントから利用できます。Claude Codeの例（環境変数 `CHESS_EVENT_MAP_MCP_TOKEN` に専用シークレットを設定済みとします）:

```sh
claude mcp add --transport http chess-event-map \
  https://chess-event-map.stu345.com/mcp \
  --header "Authorization: Bearer ${CHESS_EVENT_MAP_MCP_TOKEN}"
```

このコマンドは解決済みトークンをローカル設定に保存します。共有する `--scope project` は使わず、その設定も公開しないでください。
ブラウザ版Claudeなど、独自Authorizationヘッダーを設定できない接続方法には対応していません（MCP接続のOAuthサーバーは提供しません）。

ツール:

- `x_posting_status_tool`: 管理者が選択した投稿先の名前とX IDを確認。
- `publish_event_to_x_tool`: イベント告知を公開投稿。`event_uid`（イベント詳細URLの末尾のID）、`text`（URLを含む完成済み本文）、`request_id`（UUID等、英数字・ハイフン・アンダースコア、100文字以内）を指定。

例: 「イベントURL https://chess-event-map.stu345.com/events/実際のID を告知したい。投稿先を確認し、本文を作成して見せて。私が公開を指示したら、その本文をXへ投稿して」。

`publish_event_to_x_tool` の引数例:

```json
{
  "event_uid": "実際のイベントのpublic_uid",
  "text": "チェス大会のお知らせ！ 詳細はこちら https://chess-event-map.stu345.com/events/実際のID",
  "request_id": "f6b2713e-43c4-4acf-aed0-c8a41877372f"
}
```

本文をそのまま送信します。文字数・URL換算・アカウントの投稿上限はX側の判定に従います。画像やスレッドの投稿には対応していません。イベントの既存 `x_post_url`（イベント情報の取得元）は変更しません。

## 再試行と履歴

同じ `request_id` と同じイベント・本文の再送は、成功済みなら保存した投稿URLを返します。異なる内容へのID再利用は拒否します。送信前に履歴を予約し、タイムアウト・プロセス停止・エラー時の自動再投稿を防ぎます。

管理画面に最新50件の本文・投稿先・状態・結果を表示します。`pending` / `failed` は同じIDで再送しません。Xが受理した直後の通信切断などでは成功か判別できないため、まずX側と履歴を確認し、未投稿と確認できた場合に限り新しい `request_id` で指示してください。履歴を削除するとそのIDの重複防止情報も失われます。履歴があるイベントの削除は拒否します。

## 参照

- [X OAuth 2.0 + PKCE](https://docs.x.com/fundamentals/authentication/oauth-2-0/authorization-code)
- [X Create Posts](https://docs.x.com/x-api/posts/create-post)
- [MCP Ruby SDK](https://ruby.sdk.modelcontextprotocol.io/server/transports/)
- [Claude Code MCP接続](https://code.claude.com/docs/en/mcp)
