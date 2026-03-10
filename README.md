# claw-server-kitting 🖥️

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

MacBook をホームサーバーとしてキッティングし、OpenClaw を導入するスクリプト集。

---

## 目次

- [構成](#構成)
- [クイックスタート](#クイックスタート)
- [setup-mac-server.sh がやること](#setup-mac-serversh-がやること)
- [検証](#検証)
- [ドキュメント](#ドキュメント)
- [二台目の Mac に導入する場合](#二台目の-mac-に導入する場合)
- [手動確認が必要な項目](#手動確認が必要な項目)
- [ライセンス](#ライセンス)

---

## 構成

```
setup-mac-server.sh       # OS設定・ツールインストール
setup-openclaw.sh         # OpenClaw導入
verify.sh                 # post-install検証スクリプト
templates/                # Workspace雛形ファイル
docs/
  ├── troubleshooting.md  # トラブルシューティング
  ├── channel-setup.md    # チャンネル接続（Discord/Slack/Telegram）
  ├── tailscale-setup.md  # Tailscale設定
  ├── second-mac.md       # 二台目Mac導入ガイド
  └── memory-lancedb-pro.md # 記憶プラグイン導入ガイド
.env.example              # ホスト名などの設定テンプレート
```

## クイックスタート

### 1. リポジトリをクローン

```bash
git clone git@github.com:your-org/claw-server-kitting.git /tmp/claw-server-kitting
cd /tmp/claw-server-kitting
```

### 2. 設定ファイルを作成

```bash
cp .env.example .env
# .env を編集してホスト名を設定
```

### 3. サーバーキッティング実行

```bash
sudo bash setup-mac-server.sh --hostname <your-hostname>
# 例: sudo bash setup-mac-server.sh --hostname my-server
```

または `.env` にホスト名を書いておけば引数不要:
```bash
sudo bash setup-mac-server.sh
```

### 4. OpenClaw 導入

```bash
bash setup-openclaw.sh
```

### 5. 検証

```bash
bash verify.sh
```

## setup-mac-server.sh がやること

| # | 項目 | 内容 |
|---|------|------|
| 1 | ホスト名 | 指定した名前に設定 |
| 2 | スリープ | 完全無効化 |
| 3 | クラムシェル | 蓋閉じ運用対応 |
| 4 | 自動再起動 | フリーズ/停電後に自動復帰 |
| 5 | 自動ログイン | 再起動後に自動ログイン |
| 6 | UI最適化 | ターミナルPro、Dock縮小、マウス最速 |
| 7 | SSH | リモートログイン有効化 |
| 8 | 画面共有 | VNC/ARD有効化 |
| 9 | ファイアウォール | 有効化（署名済みアプリ許可） |
| 10 | アップデート | セキュリティパッチ自動、OS手動 |
| 11 | Spotlight | 無効化（リソース節約） |
| 12 | NTP | 時刻同期 |
| 13 | Xcode CLT | チェック |
| 14-16 | Homebrew + ツール | node, git, jq, Slack, Discord, Docker, Tailscale等 |
| 17 | nodenv | 最新LTS Node.js |
| 18 | pm2 | プロセスマネージャー |
| 19 | SSH鍵 | GitHub用 ed25519 |
| 20 | zsh | プロンプト、補完、エイリアス |
| 21 | caffeinate | スリープ防止バックアップ |

## 検証

`verify.sh` でインストール後の状態を一括チェックできます:

```bash
bash verify.sh
```

チェック項目:
- ✅ macOS 設定（スリープ、SSH、ファイアウォール等）
- ✅ ツール（Homebrew, Node.js, nodenv, pm2, Docker, Tailscale）
- ✅ OpenClaw（コマンド、Gateway、Workspace）
- ✅ ネットワーク・セキュリティ

## ドキュメント

| ドキュメント | 内容 |
|-------------|------|
| [トラブルシューティング](docs/troubleshooting.md) | VNC黒画面、CDP設定、Discord接続等の実体験ベースの解決策 |
| [チャンネル接続](docs/channel-setup.md) | Discord / Slack / Telegram の接続手順 |
| [Tailscale セットアップ](docs/tailscale-setup.md) | VPN設定、MagicDNS、SSH over Tailscale |
| [二台目Mac導入](docs/second-mac.md) | 二台目追加時の手順と注意点 |

## 二台目の Mac に導入する場合

二台目以降の Mac を追加する場合は [docs/second-mac.md](docs/second-mac.md) を参照。

主なポイント:
- **同じスクリプト**で OS キッティング + OpenClaw 導入が可能
- **API キー**は一台目と共有可能
- **Discord Bot** は二台目用に新しく作成する必要あり
- **Tailscale** で一台目と自動接続

```bash
# 二台目セットアップ（最短手順）
git clone git@github.com:your-org/claw-server-kitting.git /tmp/claw-server-kitting
cd /tmp/claw-server-kitting
sudo bash setup-mac-server.sh --hostname my-second-mac
bash setup-openclaw.sh
bash verify.sh
```

## 手動確認が必要な項目

1. GitHub に SSH公開鍵を登録
2. システム設定 > 共有 > 画面共有 を確認
3. Tailscale を起動してログイン
4. Docker Desktop を起動
5. Slack / Discord にログイン
6. 自動ログインの確認

## ライセンス

MIT
