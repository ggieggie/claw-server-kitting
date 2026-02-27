# トラブルシューティングガイド 🔧

実際の導入・運用で遭遇した問題と解決策をまとめています。

---

## 目次

- [VNC 画面が真っ黒になる](#vnc-画面が真っ黒になる)
- [SSH 接続できない](#ssh-接続できない)
- [Chrome CDP デバッグモードの起動](#chrome-cdp-デバッグモードの起動)
- [CDP browser.close() で接続が壊れる](#cdp-browserclose-で接続が壊れる)
- [OpenClaw config.patch 連続実行でクラッシュ](#openclaw-configpatch-連続実行でクラッシュ)
- [OpenClaw が .env を読まない](#openclaw-が-env-を読まない)
- [Discord Bot が応答しない](#discord-bot-が応答しない)
- [スリープ設定](#スリープ設定)
- [Tailscale 経由で Gateway にアクセスできない](#tailscale-経由で-gateway-にアクセスできない)
- [nodenv / openclaw コマンドが見つからない](#nodenv--openclaw-コマンドが見つからない)

---

## VNC 画面が真っ黒になる

### 症状

クラムシェルモード（蓋閉じ）で運用中、VNC（画面共有）で接続すると画面が真っ黒。マウスカーソルだけ見える、または完全に黒い。

### 原因

macOS はクラムシェルモード + 外部ディスプレイなし + `displaysleep > 0` の状態だと、ディスプレイスリープ後に画面バッファを破棄する。VNC はこのバッファを読み取るため、バッファがないと黒画面になる。

### 解決策

```bash
# ディスプレイスリープを無効化（0 = 無効）
sudo pmset -a displaysleep 0

# 確認
pmset -g | grep displaysleep
# displaysleep  0  ← これが正しい
```

### 補足

- `displaysleep 0` にしても物理的な消費電力への影響は軽微（蓋閉じならバックライトなし）
- Apple Silicon Mac ではスクリーンセーバーも無効にしておくと安心:
  ```bash
  defaults -currentHost write com.apple.screensaver idleTime 0
  ```

---

## SSH 接続できない

### 症状

`ssh user@hostname` で `Connection refused` になる。

### 原因

macOS はデフォルトで SSH（リモートログイン）が無効。

### 解決策

```bash
# SSH を有効化
sudo systemsetup -setremotelogin on

# 確認
sudo systemsetup -getremotelogin
# Remote Login: On ← これが正しい
```

### 確認方法

```bash
# ローカルでテスト
ssh localhost
# → ログインできれば OK

# ポート確認
sudo lsof -i :22
# → sshd が LISTEN していれば OK
```

---

## Chrome CDP デバッグモードの起動

### 症状

Chrome をリモートデバッグモード（`--remote-debugging-port=9222`）で起動したいが、Chrome 145+ では起動に失敗する、またはプロファイルが読めない。

### 原因

Chrome 145 以降、`--remote-debugging-port` を使う場合に `--user-data-dir` の指定が必須になった。かつ、**デフォルトの Chrome データディレクトリ**（`~/Library/Application Support/Google/Chrome`）をそのまま指定すると拒否される。

### 解決策: シンボリックリンク方式

既存のプロファイルをシンボリックリンクで別ディレクトリに見せかける:

```bash
# 1. CDP用ディレクトリを作成
mkdir -p /tmp/chrome-cdp

# 2. 使いたいプロファイルをシンボリックリンク
#    ※ "Profile 26" は自分のプロファイル名に置き換える
#    プロファイル一覧: ls ~/Library/Application\ Support/Google/Chrome/ | grep Profile
ln -sf "$HOME/Library/Application Support/Google/Chrome/Profile 26" "/tmp/chrome-cdp/Profile 26"

# 3. Local State ファイルをコピー（必須）
cp "$HOME/Library/Application Support/Google/Chrome/Local State" /tmp/chrome-cdp/

# 4. Chrome を CDP モードで起動
open -a "Google Chrome" --args \
  --remote-debugging-port=9222 \
  --user-data-dir="/tmp/chrome-cdp"
```

### 確認方法

```bash
# CDP エンドポイントの確認
curl -s http://localhost:9222/json/version | jq .

# 開いているタブ一覧
curl -s http://localhost:9222/json/list | jq '.[].url'
```

### 注意点

- Chrome が既に起動している場合は一旦完全に終了してから起動すること
- `/tmp/chrome-cdp` は再起動で消えるので、起動スクリプトに組み込むのが良い

---

## CDP browser.close() で接続が壊れる

### 症状

Playwright の `connectOverCDP` で Chrome に接続し、`browser.close()` を呼ぶ → 再度 `connectOverCDP` すると `/json/list` が空になり、タブが見えなくなる。

### 原因

`browser.close()` は CDP の Target discovery を破壊する。Playwright がブラウザプロセス自体のクリーンアップを試みるため、CDP の内部状態が不整合になる。

### 解決策

```javascript
// ❌ やってはいけない
const browser = await chromium.connectOverCDP('http://localhost:9222');
// ... 作業 ...
await browser.close(); // ← これが壊す

// ✅ 正しい方法
const browser = await chromium.connectOverCDP('http://localhost:9222');
const context = browser.contexts()[0];
const page = context.pages()[0];
// ... 作業 ...
await page.close(); // ← ページだけ閉じる
// browser.close() は呼ばない
```

### 壊れた場合の復旧

Chrome を完全に再起動する:

```bash
# Chrome を終了
pkill -f "Google Chrome"
sleep 2

# 再起動（CDP モード）
open -a "Google Chrome" --args \
  --remote-debugging-port=9222 \
  --user-data-dir="/tmp/chrome-cdp"
```

---

## OpenClaw config.patch 連続実行でクラッシュ

### 症状

`openclaw config.patch` を短時間に連続で実行すると、Discord WebSocket がクラッシュし Bot がオフラインになる。

### 原因

config.patch は設定変更のたびにプラグイン（Discord 含む）の再接続を行う。短時間に複数回実行すると WebSocket の接続/切断が競合する。

### 対策

- config.patch は **5秒以上の間隔** を空けて実行する
- 複数の設定変更がある場合は、1回の config.patch にまとめる
- クラッシュした場合: `openclaw gateway restart`

---

## OpenClaw が .env を読まない

### 症状

`.env` ファイルに API キーやトークンを書いたのに反映されない。

### 原因

OpenClaw は `.env` ファイルを自動で読み込まない。

### 解決策

トークンや API キーは以下のいずれかで渡す:

```bash
# 方法1: openclaw configure で対話的に設定
openclaw configure

# 方法2: config.yaml に直接記載
# ~/.openclaw/config.yaml

# 方法3: 環境変数として export
export ANTHROPIC_API_KEY="sk-ant-..."
```

---

## Discord Bot が応答しない

### 症状

Discord Bot がオンラインなのにメッセージに反応しない。またはオフラインのまま。

### 原因

OpenClaw の Discord 接続には **2つの設定** が両方 true である必要がある:

1. `channels.discord.enabled: true` — チャンネルとしての有効化
2. `plugins.entries.discord.enabled: true` — プラグインとしての有効化

### 確認方法

```bash
# 現在の設定を確認
openclaw config.get channels.discord.enabled
openclaw config.get plugins.entries.discord.enabled

# 両方 true にする
openclaw config.patch channels.discord.enabled true
# ← 5秒待つ
openclaw config.patch plugins.entries.discord.enabled true
```

### Discord Developer Portal 側のチェックリスト

- [ ] Bot Token が正しいか
- [ ] **Message Content Intent** が ON か（Privileged Gateway Intents）
- [ ] Bot がサーバーに追加されているか
- [ ] Bot にメッセージ読み取り権限があるか

---

## スリープ設定

### 症状

サーバーが突然応答しなくなる。SSH も VNC も切れる。

### 原因

macOS のスリープが有効になっている。

### 解決策

サーバー用途では全スリープを無効にする:

```bash
# 全スリープ無効化
sudo pmset -a displaysleep 0 sleep 0 disksleep 0

# 確認
pmset -g
```

期待される出力:
```
 displaysleep      0
 sleep             0
 disksleep         0
```

### caffeinate バックアップ

追加の保険として caffeinate をバックグラウンドで走らせる:

```bash
# pm2 で永続化
pm2 start "caffeinate -s" --name caffeinate
pm2 save
```

---

## Tailscale 経由で Gateway にアクセスできない

### 症状

Tailscale 経由（`http://100.x.x.x:18789`）で OpenClaw Gateway にアクセスできない。ローカル（`http://localhost:18789`）では問題なし。

### 原因

Gateway の bind が `loopback`（デフォルト）だと `127.0.0.1` にしかバインドされない。Tailscale の仮想 NIC からのアクセスは拒否される。

### 解決策

```bash
# bind を lan に変更
openclaw config.patch gateway.bind lan

# Gateway 再起動
openclaw gateway restart

# 確認
curl http://$(tailscale ip -4):18789/health
```

---

## nodenv / openclaw コマンドが見つからない

### 症状

新しいターミナルセッションを開くと `openclaw: command not found` や `nodenv: command not found` になる。

### 原因

nodenv の初期化が `.zshrc` に設定されていない。

### 解決策

```bash
# .zshrc に追加
echo 'export PATH="$HOME/.nodenv/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(nodenv init -)"' >> ~/.zshrc

# 反映
source ~/.zshrc

# 確認
which openclaw
openclaw --version
```

### 確認ポイント

```bash
# nodenv がインストールしたグローバル Node のパス
nodenv which node
# → /Users/<user>/.nodenv/versions/22.x.x/bin/node

# openclaw のパス
nodenv which openclaw
# → /Users/<user>/.nodenv/versions/22.x.x/bin/openclaw
```
