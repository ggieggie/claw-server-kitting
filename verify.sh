#!/bin/bash
#
# verify.sh — claw-server-kitting post-install 検証スクリプト
# 使い方: bash verify.sh
#
set -u

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "  ${GREEN}✅ PASS${NC}  $1"; ((PASS++)); }
fail() { echo -e "  ${RED}❌ FAIL${NC}  $1"; ((FAIL++)); }
warn() { echo -e "  ${YELLOW}⚠️  WARN${NC}  $1"; ((WARN++)); }
section() { echo -e "\n${CYAN}${BOLD}━━━ $1 ━━━${NC}"; }

echo ""
echo "========================================="
echo " 🔍 claw-server-kitting 検証スクリプト"
echo "========================================="

# ============================================
# macOS 設定
# ============================================
section "macOS 設定"

# ホスト名
HOSTNAME=$(scutil --get ComputerName 2>/dev/null || hostname)
pass "ホスト名: $HOSTNAME"

# スリープ設定
for key in displaysleep sleep disksleep; do
  val=$(pmset -g 2>/dev/null | grep -w "$key" | awk '{print $2}')
  if [ "$val" = "0" ]; then
    pass "$key = 0 (無効)"
  else
    fail "$key = ${val:-unknown} (0 であるべき)"
  fi
done

# クラムシェル
clamshell=$(pmset -g 2>/dev/null | grep -i "lidwake" | awk '{print $2}')
if [ "$clamshell" = "1" ]; then
  pass "lidwake = 1 (クラムシェル対応)"
else
  warn "lidwake = ${clamshell:-unknown}"
fi

# 自動再起動
autorestart=$(pmset -g 2>/dev/null | grep -i "autorestart" | awk '{print $2}')
if [ "$autorestart" = "1" ]; then
  pass "autorestart = 1"
else
  warn "autorestart = ${autorestart:-unknown}"
fi

# SSH
ssh_status=$(sudo systemsetup -getremotelogin 2>/dev/null | grep -i "on" && echo "on" || echo "off")
if echo "$ssh_status" | grep -q "on"; then
  pass "SSH (リモートログイン) 有効"
else
  fail "SSH (リモートログイン) 無効"
fi

# ファイアウォール
fw=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null)
if echo "$fw" | grep -qi "enabled"; then
  pass "ファイアウォール 有効"
else
  warn "ファイアウォール 無効"
fi

# NTP
ntp_enabled=$(sudo systemsetup -getusingnetworktime 2>/dev/null)
if echo "$ntp_enabled" | grep -qi "on"; then
  pass "NTP 有効"
else
  warn "NTP 設定不明"
fi

# ============================================
# ツール
# ============================================
section "ツール"

for cmd in brew node npm git jq; do
  if command -v "$cmd" &>/dev/null; then
    ver=$($cmd --version 2>/dev/null | head -1)
    pass "$cmd ($ver)"
  else
    fail "$cmd が見つかりません"
  fi
done

# nodenv
if command -v nodenv &>/dev/null; then
  pass "nodenv ($(nodenv --version 2>/dev/null))"
else
  fail "nodenv が見つかりません"
fi

# pm2
if command -v pm2 &>/dev/null; then
  pass "pm2 ($(pm2 --version 2>/dev/null))"
else
  warn "pm2 が見つかりません"
fi

# docker
if command -v docker &>/dev/null; then
  if docker info &>/dev/null 2>&1; then
    pass "Docker (稼働中)"
  else
    warn "Docker インストール済みだが起動していない"
  fi
else
  warn "Docker が見つかりません（オプション）"
fi

# tailscale
if command -v tailscale &>/dev/null; then
  ts_status=$(tailscale status --json 2>/dev/null | grep -o '"BackendState":"[^"]*"' | cut -d'"' -f4)
  if [ "$ts_status" = "Running" ]; then
    ts_ip=$(tailscale ip -4 2>/dev/null)
    pass "Tailscale 接続中 ($ts_ip)"
  else
    warn "Tailscale インストール済みだが未接続 ($ts_status)"
  fi
else
  warn "Tailscale が見つかりません（オプション）"
fi

# ============================================
# OpenClaw
# ============================================
section "OpenClaw"

if command -v openclaw &>/dev/null; then
  pass "openclaw コマンド存在"
  oc_ver=$(openclaw --version 2>/dev/null || echo "unknown")
  pass "バージョン: $oc_ver"

  gw_status=$(openclaw gateway status 2>/dev/null)
  if echo "$gw_status" | grep -qi "running\|online\|active"; then
    pass "Gateway 稼働中"
  else
    fail "Gateway 停止中: $gw_status"
  fi
else
  fail "openclaw コマンドが見つかりません"
fi

# Workspace
WORKSPACE="$HOME/.openclaw/workspace"
if [ -d "$WORKSPACE" ]; then
  pass "Workspace 存在: $WORKSPACE"
else
  fail "Workspace が見つかりません: $WORKSPACE"
fi

for f in AGENTS.md SOUL.md USER.md; do
  if [ -f "$WORKSPACE/$f" ]; then
    pass "$f 存在"
  else
    fail "$f が見つかりません"
  fi
done

# ============================================
# ネットワーク
# ============================================
section "ネットワーク"

if ssh -o ConnectTimeout=3 -o BatchMode=yes localhost true 2>/dev/null; then
  pass "SSH localhost 接続OK"
else
  warn "SSH localhost 接続不可（鍵設定が必要かも）"
fi

# ============================================
# セキュリティ
# ============================================
section "セキュリティ"

# Spotlight
spotlight=$(mdutil -s / 2>/dev/null)
if echo "$spotlight" | grep -qi "disabled"; then
  pass "Spotlight 無効"
else
  warn "Spotlight 有効（リソース節約のため無効推奨）"
fi

# ============================================
# 結果サマリー
# ============================================
echo ""
echo "========================================="
echo -e " 結果: ${GREEN}PASS=$PASS${NC}  ${RED}FAIL=$FAIL${NC}  ${YELLOW}WARN=$WARN${NC}"
echo "========================================="

if [ "$FAIL" -gt 0 ]; then
  echo -e " ${RED}問題が見つかりました。上記の FAIL 項目を確認してください。${NC}"
  exit 1
else
  echo -e " ${GREEN}全チェック通過！ 🎉${NC}"
  exit 0
fi
