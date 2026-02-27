#!/bin/bash
#
# OpenClaw 導入スクリプト
# 前提: setup-mac-server.sh 実行済み（nodenv, Node.js インストール済み）
# 使い方: bash setup-openclaw.sh
#
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
err()  { echo -e "${RED}❌ $1${NC}"; }

echo "========================================="
echo " 🐾 OpenClaw 導入スクリプト"
echo "========================================="
echo ""

# ============================================
# 1. 前提チェック
# ============================================
echo "--- 1. 前提チェック ---"

# nodenv
if command -v nodenv &>/dev/null; then
  eval "$(nodenv init -)"
  log "nodenv OK"
else
  err "nodenv が見つかりません。先に setup-mac-server.sh を実行してください"
  exit 1
fi

# Node.js
if command -v node &>/dev/null; then
  NODE_VER=$(node -v)
  log "Node.js $NODE_VER"
  # Node 22+ チェック
  MAJOR=$(echo "$NODE_VER" | sed 's/v//' | cut -d. -f1)
  if [ "$MAJOR" -lt 22 ]; then
    warn "Node 22+ が必要です。最新版をインストールします..."
    LATEST=$(nodenv install -l | grep -E '^\s*22\.' | tail -1 | tr -d ' ')
    nodenv install "$LATEST"
    nodenv global "$LATEST"
    eval "$(nodenv init -)"
    log "Node $LATEST インストール完了"
  fi
else
  err "Node.js が見つかりません"
  exit 1
fi

# npm
if command -v npm &>/dev/null; then
  log "npm $(npm -v)"
else
  err "npm が見つかりません"
  exit 1
fi

# ============================================
# 2. OpenClaw インストール
# ============================================
echo ""
echo "--- 2. OpenClaw インストール ---"

if command -v openclaw &>/dev/null; then
  CURRENT_VER=$(openclaw --version 2>/dev/null || echo "unknown")
  log "OpenClaw 既にインストール済み ($CURRENT_VER)"
  echo "  最新版に更新しますか？ (y/N)"
  read -r UPDATE
  if [ "$UPDATE" = "y" ] || [ "$UPDATE" = "Y" ]; then
    npm install -g openclaw@latest
    nodenv rehash
    log "OpenClaw 更新完了"
  fi
else
  echo "OpenClaw をインストール中..."
  npm install -g openclaw@latest
  nodenv rehash
  log "OpenClaw インストール完了 ($(openclaw --version 2>/dev/null))"
fi

# ============================================
# 3. オンボーディング
# ============================================
echo ""
echo "--- 3. オンボーディング ---"
echo ""
echo "  オンボーディング方式を選んでください:"
echo "    1) 対話式（ウィザード） — 初めての場合はこちら"
echo "    2) 自動（APIキーを入力） — 手早く設定"
echo "    3) スキップ — 後で手動設定"
echo ""
read -rp "  選択 (1/2/3): " ONBOARD_CHOICE

case "$ONBOARD_CHOICE" in
  1)
    echo ""
    log "対話式オンボーディングを開始します..."
    echo ""
    openclaw onboard --install-daemon
    ;;
  2)
    echo ""
    read -rp "  Anthropic API Key: " API_KEY
    if [ -z "$API_KEY" ]; then
      err "API Key が入力されていません"
      exit 1
    fi

    read -rp "  Gateway bind (loopback/lan) [loopback]: " BIND_CHOICE
    BIND_CHOICE=${BIND_CHOICE:-loopback}

    openclaw onboard --non-interactive \
      --mode local \
      --auth-choice apiKey \
      --anthropic-api-key "$API_KEY" \
      --gateway-port 18789 \
      --gateway-bind "$BIND_CHOICE" \
      --install-daemon \
      --daemon-runtime node \
      --skip-skills

    log "自動オンボーディング完了"
    ;;
  3)
    warn "オンボーディングをスキップしました"
    warn "後で openclaw onboard を実行してください"
    ;;
  *)
    warn "無効な選択。スキップします"
    ;;
esac

# ============================================
# 4. Workspace 雛形配置
# ============================================
echo ""
echo "--- 4. Workspace 雛形 ---"

WORKSPACE="$HOME/.openclaw/workspace"
mkdir -p "$WORKSPACE/memory"

# テンプレートディレクトリ（このリポジトリ内）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/templates"

if [ ! -d "$TEMPLATE_DIR" ]; then
  err "templates/ ディレクトリが見つかりません"
  exit 1
fi

TEMPLATE_FILES=(AGENTS.md SOUL.md USER.md IDENTITY.md MEMORY.md TOOLS.md HEARTBEAT.md BOOTSTRAP.md)

for tpl in "${TEMPLATE_FILES[@]}"; do
  if [ ! -f "$WORKSPACE/$tpl" ]; then
    cp "$TEMPLATE_DIR/$tpl" "$WORKSPACE/$tpl"
    log "$tpl 作成"
  else
    warn "$tpl 既に存在（スキップ）"
  fi
done

# ============================================
# 5. 動作確認
# ============================================
echo ""
echo "--- 5. 動作確認 ---"

if command -v openclaw &>/dev/null; then
  openclaw doctor 2>/dev/null && log "openclaw doctor OK" || warn "openclaw doctor で問題あり"
  GATEWAY_STATUS=$(openclaw gateway status 2>/dev/null || echo "unknown")
  echo "  Gateway: $GATEWAY_STATUS"
else
  warn "openclaw コマンドが見つかりません。ターミナルを再起動してください"
fi

# ============================================
# 完了
# ============================================
echo ""
echo "========================================="
echo " 🎉 OpenClaw 導入完了！"
echo "========================================="
echo ""
echo " 📋 次のステップ:"
echo "  1. openclaw status で状態確認"
echo "  2. openclaw dashboard でブラウザUIを開く"
echo "  3. チャンネル接続（Discord等）: openclaw configure"
echo "  4. Workspace のカスタマイズ: $WORKSPACE/"
echo ""
echo " 📁 Workspace: $WORKSPACE"
echo "  - SOUL.md    → AIの性格設定"
echo "  - USER.md    → ユーザー情報"
echo "  - AGENTS.md  → 動作ルール"
echo "  - MEMORY.md  → 長期記憶"
echo ""
echo "========================================="
