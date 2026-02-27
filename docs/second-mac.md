# 二台目 Mac 導入ガイド 🖥️🖥️

一台目のセットアップが完了した後、二台目の Mac を追加する手順。

---

## 一台目との違い

| 項目 | 一台目 | 二台目 |
|------|--------|--------|
| OS キッティング | フルセットアップ | 同じ（`setup-mac-server.sh`） |
| OpenClaw | 新規オンボーディング | API キー流用可能 |
| Discord Bot | 新規作成 | 新しい Bot を作成 or 同じ Bot は不可 |
| Tailscale | 初回ログイン | 同じアカウントでログイン |
| Workspace | 新規作成 | テンプレートから or 一台目からコピー |

---

## セットアップ手順

### 1. OS キッティング

一台目と同じ:

```bash
git clone git@github.com:your-org/claw-server-kitting.git /tmp/claw-server-kitting
cd /tmp/claw-server-kitting

# ホスト名を変えて実行（例: my-server2）
sudo bash setup-mac-server.sh --hostname my-server2
```

### 2. OpenClaw 導入

```bash
bash setup-openclaw.sh
```

オンボーディングで **同じ API キー**（Anthropic API Key）を使える。一台目と同じキーでOK。

### 3. Tailscale 接続

```bash
sudo tailscale up
# → 同じ Tailscale アカウントでログイン
# → 自動的に一台目と同じネットワークに参加

# 接続確認
tailscale status
# → 一台目と二台目の両方が表示される
```

### 4. 検証

```bash
bash verify.sh

# 一台目から二台目にアクセスできるか確認
# （一台目で実行）
curl http://my-server2:18789/health
```

---

## Discord Bot の追加

⚠️ **一つの Discord Bot トークンを複数の Gateway で使うことはできない。** 二台目用に新しい Bot を作成する。

### 方法: 同じサーバーに二台目 Bot を追加

1. [Discord Developer Portal](https://discord.com/developers/applications) で **新しい Application** を作成（例: `MyClaw-2`）
2. Bot Token を取得
3. Message Content Intent を ON
4. OAuth2 URL Generator で同じサーバーに追加
5. 二台目の OpenClaw に設定:

```bash
openclaw config.patch channels.discord.enabled true
openclaw config.patch channels.discord.token "NEW_BOT_TOKEN"
openclaw config.patch channels.discord.guildId "SAME_GUILD_ID"
sleep 5
openclaw config.patch plugins.entries.discord.enabled true
```

### チャンネルの使い分け

二つの Bot が同じチャンネルにいると混乱するので、チャンネルを分けるのがおすすめ:

- `#claw-main` — 一台目の Bot が監視
- `#claw-sub` — 二台目の Bot が監視

Discord のチャンネル権限で Bot ごとにアクセスを制限できる。

---

## Workspace の同期

二台目の Workspace をどう管理するかの選択肢:

### 方法A: Git 管理（推奨）

各 Mac の Workspace を Git リポジトリにして、共通部分を同期:

```bash
cd ~/.openclaw/workspace
git init
git remote add origin git@github.com:yourname/claw-workspace.git

# SOUL.md, AGENTS.md, TOOLS.md などを共有
# MEMORY.md, memory/ は .gitignore に追加（Mac固有のため）
```

`.gitignore` の例:
```
MEMORY.md
memory/
*.local
```

### 方法B: rsync で手動同期

```bash
# 一台目 → 二台目にコピー
rsync -avz --exclude='MEMORY.md' --exclude='memory/' \
  ~/.openclaw/workspace/ \
  my-server2:~/.openclaw/workspace/
```

### 方法C: 完全独立

それぞれの Mac で独自の Workspace を持つ。用途が違う場合はこれが最もシンプル。

---

## 設定の共有

一台目の config を参考にして二台目を設定する場合:

```bash
# 一台目で設定をエクスポート
cat ~/.openclaw/config.yaml

# 二台目にコピー（API キーやモデル設定を流用）
scp my-server:~/.openclaw/config.yaml /tmp/config-reference.yaml
# → 手動で必要な部分をコピー（Discord Token は変える必要あり）
```

⚠️ config.yaml をそのままコピーすると Discord Token が重複するので注意。
