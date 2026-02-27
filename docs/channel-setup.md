# チャンネル接続ガイド 📡

OpenClaw にチャットプラットフォーム（Discord / Slack / Telegram）を接続する手順。

---

## 目次

- [Discord](#discord)
- [Slack](#slack)
- [Telegram](#telegram)

---

## Discord

### 1. Bot の作成

1. [Discord Developer Portal](https://discord.com/developers/applications) にアクセス
2. **New Application** → アプリ名を入力（例: `MyClaw`）→ Create
3. 左メニュー **Bot** をクリック
4. **Reset Token** → トークンをコピー（⚠️ 一度しか表示されない。安全な場所に保存）

### 2. Privileged Gateway Intents の設定

Bot ページの下部、**Privileged Gateway Intents** セクション:

- [x] **MESSAGE CONTENT INTENT** — 必須。これが OFF だとメッセージ本文を受信できない

Save Changes を忘れずに。

### 3. サーバーへの追加

1. 左メニュー **OAuth2** → **URL Generator**
2. Scopes: `bot` にチェック
3. Bot Permissions:
   - ✅ Send Messages
   - ✅ Read Messages/View Channels
   - ✅ Read Message History
   - ✅ Add Reactions
   - ✅ Use External Emojis
   - ✅ Attach Files
   - ✅ Embed Links
   - ✅ Manage Messages
4. 生成された URL をブラウザで開く
5. Bot を追加するサーバーを選択 → Authorize

### 4. Guild ID の取得

1. Discord アプリの設定 → **詳細設定** → **開発者モード** を ON
2. サーバー名を右クリック → **サーバーIDをコピー**

### 5. OpenClaw への設定

```bash
# 方法A: 対話式
openclaw configure

# 方法B: コマンドで直接設定
openclaw config.patch channels.discord.enabled true
openclaw config.patch channels.discord.token "YOUR_BOT_TOKEN"
openclaw config.patch channels.discord.guildId "YOUR_GUILD_ID"
# ⚠️ 5秒以上間隔を空ける
sleep 5
openclaw config.patch plugins.entries.discord.enabled true
```

config.yaml の該当部分（参考）:

```yaml
channels:
  discord:
    enabled: true
    token: "YOUR_BOT_TOKEN"
    guildId: "YOUR_GUILD_ID"
    triggers:
      - type: mention    # @Bot でトリガー
      - type: keyword
        pattern: "hey claw"  # キーワードでトリガー

plugins:
  entries:
    discord:
      enabled: true
```

### 6. 動作確認

```bash
# 1. Gateway が動いているか
openclaw gateway status

# 2. Gateway 再起動（設定反映）
openclaw gateway restart

# 3. Discord でBotがオンラインか確認（緑の●が付く）

# 4. Bot にメンションしてメッセージを送る
#    @MyClaw こんにちは
#    → 応答があれば成功 🎉
```

### トラブルシューティング

| 症状 | 確認ポイント |
|------|-------------|
| Bot がオフライン | Token が正しいか / `channels.discord.enabled` と `plugins.entries.discord.enabled` の両方が true か |
| メンションに反応しない | Message Content Intent が ON か / `triggers` に mention が設定されているか |
| 特定チャンネルだけ反応しない | Bot にそのチャンネルの閲覧権限があるか |

---

## Slack

### 1. Slack App の作成

1. [Slack API](https://api.slack.com/apps) にアクセス
2. **Create New App** → **From scratch**
3. App Name と Workspace を選択

### 2. Socket Mode の有効化

1. 左メニュー **Socket Mode** → Enable Socket Mode → ON
2. App-Level Token を生成（名前: `socket`、Scope: `connections:write`）
3. トークンをコピー（`xapp-` で始まる）

### 3. Event Subscriptions

1. 左メニュー **Event Subscriptions** → Enable Events → ON
2. **Subscribe to bot events**:
   - `message.channels`
   - `message.groups`
   - `message.im`
   - `app_mention`

### 4. OAuth & Permissions

Bot Token Scopes:
- `chat:write`
- `channels:history`
- `groups:history`
- `im:history`
- `app_mentions:read`
- `files:write`
- `reactions:write`

### 5. ワークスペースにインストール

1. 左メニュー **Install App** → **Install to Workspace**
2. Bot User OAuth Token をコピー（`xoxb-` で始まる）

### 6. OpenClaw への設定

```yaml
channels:
  slack:
    enabled: true
    botToken: "xoxb-..."
    appToken: "xapp-..."

plugins:
  entries:
    slack:
      enabled: true
```

---

## Telegram

### 1. Bot の作成

1. Telegram で [@BotFather](https://t.me/botfather) を検索
2. `/newbot` コマンドを送信
3. Bot 名と username を入力
4. トークンを受け取る（`123456:ABC-DEF...` の形式）

### 2. OpenClaw への設定

```yaml
channels:
  telegram:
    enabled: true
    token: "123456:ABC-DEF..."

plugins:
  entries:
    telegram:
      enabled: true
```

### 3. 動作確認

```bash
openclaw gateway restart

# Telegram で Bot を検索してメッセージを送る
# → 応答があれば成功
```

### 補足

- Telegram Bot はグループに追加することもできる
- グループで使う場合は BotFather で `/setprivacy` → Disable（全メッセージ受信）
