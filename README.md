# chess-event-map
チェスイベントマップ
https://chess-event-map.stu345.com/

## Development
1. `docker compose up`
2. open `localhost:3066`

### credentials
`docker compose run -e EDITOR=vim web rails credentials:edit`

### Production
- copy config/master.key (this file is ignored from git)
    - or you can recreate credentials.yml.enc and master.key: 
        - `rm credentials.yml.enc`
        - `docker compose run -e EDITOR=vim web rails credentials:edit`
            - you need to set `Rails.application.credentials` variables
- `docker compose -f docker-compose.production.yml build`
- `docker compose -f docker-compose.production.yml up -d`
- reset database: `docker compose -f docker-compose.production.yml run web rails db:migrate:reset RAILS_ENV=production DISABLE_DATABASE_ENVIRONMENT_CHECK=1`
- jobを使えるようにする: `docker compose -f docker-compose.production.yml run web rails db:prepare_solid RAILS_ENV=production`

## Admin
### create user
see seed.rb

## Xへの投稿・MCP

別のXアカウントをOAuth認証し、管理画面で選んだアカウントからAI経由でイベントを告知できます。
設定・認証・Claude Code接続手順は [X投稿ガイド](docs/x-posting.md) を参照してください。
