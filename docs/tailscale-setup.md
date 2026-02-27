# Tailscale セットアップガイド 🌐

複数の Mac をセキュアに接続し、どこからでも OpenClaw Gateway にアクセスできるようにする。

---

## Tailscale とは

Tailscale は WireGuard ベースのメッシュ VPN。各デバイスに `100.x.x.x` のプライベート IP が割り当てられ、NAT 越えも自動。ポート開放不要でサーバーにアクセスできる。

---

## インストール

```bash
# Homebrew（CLI のみ・サーバー向き）
brew install tailscale

# または Mac App Store（GUI あり）
# https://apps.apple.com/app/tailscale/id1475387142
```

CLI 版の場合、デーモンを起動:

```bash
sudo brew services start tailscale
```

---

## 初回ログイン

```bash
sudo tailscale up
# → ブラウザが開くので、Google / GitHub / Microsoft 等でログイン
```

---

## IP アドレスの確認

```bash
# 自分の Tailscale IP
tailscale ip -4
# → 100.x.x.x

# 接続中のデバイス一覧
tailscale status
```

---

## OpenClaw Gateway を Tailscale 経由で公開

デフォルトでは Gateway は `loopback`（localhost のみ）にバインドされている。Tailscale 経由でアクセスするには `lan` に変更する:

```bash
# bind を lan に変更
openclaw config.patch gateway.bind lan

# Gateway 再起動
openclaw gateway restart
```

これで以下の URL でアクセス可能:

```
http://100.x.x.x:18789
```

他のデバイスから確認:

```bash
# 別の Mac / PC から
curl http://100.x.x.x:18789/health
```

---

## MagicDNS

Tailscale の MagicDNS を有効にすると、IP アドレスの代わりにホスト名でアクセスできる:

1. [Tailscale Admin Console](https://login.tailscale.com/admin/dns) にアクセス
2. **MagicDNS** を有効化

```bash
# ホスト名でアクセス（例: my-server）
curl http://my-server:18789/health

# ブラウザで OpenClaw Dashboard
# http://my-server:18789
```

---

## SSH over Tailscale

Tailscale SSH を使うと、SSH 鍵の管理なしで安全に SSH 接続できる:

```bash
# サーバー側で有効化
sudo tailscale up --ssh

# クライアント側から接続
ssh my-server  # Tailscale が認証を処理
```

### 従来の SSH も併用可能

```bash
# Tailscale IP 経由で通常の SSH
ssh user@100.x.x.x
```

---

## 複数 Mac 間の構成例

```
┌─────────────┐     Tailscale     ┌─────────────┐
│  Mac 1      │◄──────────────────►│  Mac 2      │
│  (メイン)    │   100.64.0.1      │  (サブ)      │
│  Gateway    │                    │  Gateway    │
│  :18789     │                    │  :18789     │
└─────────────┘                    └─────────────┘
       ▲
       │ Tailscale
       ▼
┌─────────────┐
│  MacBook    │
│  (外出先)    │
│  100.64.0.3 │
└─────────────┘
```

どのデバイスからでも:
- `http://mac1:18789` — Mac 1 の OpenClaw
- `http://mac2:18789` — Mac 2 の OpenClaw

---

## セキュリティ

- Tailscale はエンドツーエンド暗号化（WireGuard）
- ACL で接続先を制限可能（[Admin Console](https://login.tailscale.com/admin/acls)）
- Gateway の bind を `lan` にしても、Tailscale ネットワーク内のデバイスからしかアクセスできない（インターネットには公開されない）
