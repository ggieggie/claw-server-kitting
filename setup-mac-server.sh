#!/bin/bash
#
# MacBook ホームサーバー キッティングスクリプト
# 使い方: sudo bash setup-mac-server.sh --hostname <name>
#   例: sudo bash setup-mac-server.sh --hostname taxa-dev01
#
set -e

# カラー出力
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
err()  { echo -e "${RED}❌ $1${NC}"; }

# 引数パース
SERVER_HOSTNAME=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --hostname) SERVER_HOSTNAME="$2"; shift 2 ;;
    *) err "Unknown option: $1"; exit 1 ;;
  esac
done

# .env からフォールバック
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -z "$SERVER_HOSTNAME" ] && [ -f "$SCRIPT_DIR/.env" ]; then
  SERVER_HOSTNAME=$(grep '^HOSTNAME=' "$SCRIPT_DIR/.env" 2>/dev/null | cut -d= -f2)
fi

if [ -z "$SERVER_HOSTNAME" ]; then
  err "ホスト名を指定してください: sudo bash setup-mac-server.sh --hostname <name>"
  err "または .env に HOSTNAME=<name> を設定してください"
  exit 1
fi

# root チェック
if [ "$EUID" -ne 0 ]; then
  err "sudo で実行してください: sudo bash setup-mac-server.sh --hostname $SERVER_HOSTNAME"
  exit 1
fi

ACTUAL_USER=${SUDO_USER:-$(whoami)}
ACTUAL_HOME=$(eval echo ~"$ACTUAL_USER")

echo "========================================="
echo " 🖥️  Mac ホームサーバー キッティング"
echo " ホスト名: $SERVER_HOSTNAME"
echo " ユーザー: $ACTUAL_USER"
echo "========================================="
echo ""

# ============================================
# 1. ホスト名設定
# ============================================
echo "--- 1. ホスト名設定 ---"
scutil --set HostName $SERVER_HOSTNAME
scutil --set LocalHostName $SERVER_HOSTNAME
scutil --set ComputerName $SERVER_HOSTNAME
log "ホスト名を $SERVER_HOSTNAME に設定"

# ============================================
# 2. スリープ無効化 & 電源管理
# ============================================
echo ""
echo "--- 2. スリープ無効化 & 電源管理 ---"
# コアスリープ無効化
pmset -a sleep 0
pmset -a disablesleep 1
pmset -a displaysleep 0
pmset -a hibernatemode 0
pmset -a standby 0
pmset -a autopoweroff 0

# ネットワーク安定化 (standby/DarkWake復帰時のNWスタック破損防止)
pmset -a networkoversleep 0
pmset -a tcpkeepalive 1
pmset -a ttyskeepawake 1
pmset -a womp 1

# 不要なウェイク抑制
pmset -a proximitywake 0

log "スリープ完全無効化 + ネットワーク安定化"

# ============================================
# 3. クラムシェル設定
# ============================================
echo ""
echo "--- 3. クラムシェル設定 ---"
pmset -a lidwake 0
pmset -a acwake 0

# クラムシェル時にディスプレイセッションを維持
# (画面共有接続時に画面が真っ暗にならないようにする)
defaults write /Library/Preferences/com.apple.loginwindow DesktopPicture ""
sudo -u "$ACTUAL_USER" defaults -currentHost write com.apple.screensaver idleTime 0

# パスワード要求無効化 (リモート接続時に画面ロックを防止)
sudo -u "$ACTUAL_USER" defaults write com.apple.screensaver askForPassword -int 0
sudo -u "$ACTUAL_USER" defaults write com.apple.screensaver askForPasswordDelay -int 0

# ディスプレイのオフを防止（クラムシェルでも仮想ディスプレイを維持）
# ※ 画面共有(VNC/ARD)が接続中はmacOSが仮想フレームバッファを保持する
# ※ 物理ディスプレイなしで確実に動かすにはHDMIダミープラグ推奨
log "クラムシェルモード設定完了"
warn "画面共有なしの長時間クラムシェルにはHDMIダミープラグを推奨"

# ============================================
# 4. 自動再起動（フリーズ/停電後）
# ============================================
echo ""
echo "--- 4. 自動再起動設定 ---"
pmset -a autorestart 1
systemsetup -setrestartfreeze on 2>/dev/null || true
pmset -a powernap 0
log "フリーズ/停電後の自動再起動を有効化"

# ============================================
# 5. 自動ログイン設定
# ============================================
echo ""
echo "--- 5. 自動ログイン設定 ---"
FV_STATUS=$(fdesetup status 2>/dev/null || echo "unknown")
if echo "$FV_STATUS" | grep -q "On"; then
  warn "FileVaultが有効です。自動ログインにはFileVaultの無効化が必要です"
  warn "手動で: sudo fdesetup disable → 再起動 → 再実行"
else
  defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser "$ACTUAL_USER"
  log "自動ログイン設定 (ユーザー: $ACTUAL_USER)"
  warn "パスワード入力が必要な場合は手動で: システム設定 > ユーザとグループ > 自動ログイン"
fi

# ============================================
# 6. スクリーンセーバー無効化
# ============================================
echo ""
echo "--- 5.5 ターミナル設定 ---"
# ターミナルのデフォルトプロファイルをProに（黒背景で視認性UP）
sudo -u "$ACTUAL_USER" defaults write com.apple.Terminal "Default Window Settings" -string "Pro"
sudo -u "$ACTUAL_USER" defaults write com.apple.Terminal "Startup Window Settings" -string "Pro"
# マウスカーソル速度を最速に
sudo -u "$ACTUAL_USER" defaults write -g com.apple.mouse.scaling 3.0
# Dock縮小 + 自動非表示
sudo -u "$ACTUAL_USER" defaults write com.apple.dock tilesize -int 32
sudo -u "$ACTUAL_USER" defaults write com.apple.dock autohide -bool true
killall Dock 2>/dev/null || true
log "ターミナルPro / マウス最速 / Dock縮小 設定完了"

echo ""
echo "--- 6. スクリーンセーバー無効化 ---"
# セクション3で設定済みのため、確認のみ
log "スクリーンセーバー無効化 (セクション3で設定済み)"

# ============================================
# 7. SSH有効化
# ============================================
echo ""
echo "--- 7. SSH有効化 ---"
systemsetup -setremotelogin on 2>/dev/null || launchctl load -w /System/Library/LaunchDaemons/ssh.plist 2>/dev/null || true
log "SSH (Remote Login) 有効化"

# ============================================
# 8. デスクトップ共有（VNC/ARD）
# ============================================
echo ""
echo "--- 8. デスクトップ共有 ---"
launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null || true
log "デスクトップ共有（Screen Sharing）有効化"
warn "システム設定 > 一般 > 共有 > 画面共有 で確認してください"

# ============================================
# 9. ファイアウォール
# ============================================
echo ""
echo "--- 9. ファイアウォール ---"
/usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
/usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on
/usr/libexec/ApplicationFirewall/socketfilterfw --setallowsignedapp on
/usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/sbin/sshd 2>/dev/null || true
log "ファイアウォール有効化（署名済みアプリ許可）"

# ============================================
# 10. ソフトウェアアップデート自動化
# ============================================
echo ""
echo "--- 10. ソフトウェアアップデート自動化 ---"
defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool true
defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -bool true
defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool false
log "セキュリティパッチ自動インストール有効（OSアップデートは手動）"

# ============================================
# 11. Spotlight無効化
# ============================================
echo ""
echo "--- 11. Spotlight無効化 ---"
mdutil -a -i off 2>/dev/null || true
log "Spotlightインデックス無効化（CPU/ディスク節約）"

# ============================================
# 12. NTP時刻同期
# ============================================
echo ""
echo "--- 12. 時刻同期確認 ---"
systemsetup -setusingnetworktime on 2>/dev/null || true
log "NTP時刻同期有効"

# ============================================
# 13. Xcode Command Line Tools
# ============================================
echo ""
echo "--- 13. Xcode Command Line Tools ---"
if xcode-select -p &>/dev/null; then
  log "Xcode CLT 既にインストール済み"
else
  warn "Xcode CLT が未インストール。先に xcode-select --install を実行してください"
fi

# ============================================
# 14-16: Homebrew + ツール + pm2
# ユーザー権限で実行
# ============================================
echo ""
echo "--- 15-17. Homebrew + ツール + pm2 ---"
echo "ユーザー権限で実行します..."

sudo -u "$ACTUAL_USER" bash -l << 'USEREOF'
set -e
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
log()  { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Homebrew PATHを確保
if [ -f /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -f /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# --- 15. Homebrew ---
echo ""
echo "--- 15. Homebrew ---"
if command -v brew &>/dev/null; then
  log "Homebrew 既にインストール済み"
  brew update
  log "Homebrew 更新完了"
else
  echo "Homebrew をインストール中..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # PATHに追加
  if [ -f /opt/homebrew/bin/brew ]; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  log "Homebrew インストール完了"
fi

# --- 16. 開発ツール ---
echo ""
echo "--- 16. 開発ツールインストール ---"

# CLIツール（formula）
BREW_FORMULAS=(node git jq wget htop nodenv)
echo "Homebrew formula..."
for pkg in "${BREW_FORMULAS[@]}"; do
  if brew list "$pkg" &>/dev/null; then
    echo "  $pkg: 済"
  else
    brew install "$pkg" && echo "  $pkg: ✅" || echo "  $pkg: ⚠️ スキップ"
  fi
done

# GUIアプリ（cask）
BREW_CASKS=(slack discord docker tailscale)
echo ""
echo "Homebrew cask..."
for cask in "${BREW_CASKS[@]}"; do
  if brew list --cask "$cask" &>/dev/null; then
    echo "  $cask: 済"
  else
    brew install --cask "$cask" && echo "  $cask: ✅" || echo "  $cask: ⚠️ スキップ"
  fi
done

log "開発ツールインストール完了"

# --- 17. nodenv セットアップ ---
echo ""
echo "--- 17. nodenv ---"
if command -v nodenv &>/dev/null; then
  # nodenv init を .zshrc に追加
  if ! grep -q 'nodenv init' ~/.zshrc 2>/dev/null; then
    echo 'eval "$(nodenv init -)"' >> ~/.zshrc
  fi
  # 最新LTSをインストール
  LATEST_LTS=$(nodenv install -l 2>/dev/null | grep -E '^\s*[0-9]+\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')
  if [ -n "$LATEST_LTS" ]; then
    if nodenv versions --bare | grep -q "$LATEST_LTS"; then
      echo "  Node $LATEST_LTS: 済"
    else
      nodenv install "$LATEST_LTS"
      echo "  Node $LATEST_LTS: ✅"
    fi
    nodenv global "$LATEST_LTS"
    log "nodenv セットアップ完了 (Node $LATEST_LTS)"
  else
    warn "Node LTSバージョンの取得に失敗。手動で nodenv install を実行してください"
  fi
else
  warn "nodenv が見つかりません"
fi

# --- 18. pm2 ---
echo ""
echo "--- 18. pm2 ---"
# nodenv の shims を有効化
eval "$(nodenv init -)" 2>/dev/null || true
if command -v npm &>/dev/null; then
  if command -v pm2 &>/dev/null; then
    log "pm2 既にインストール済み"
  else
    npm install -g pm2
    nodenv rehash 2>/dev/null || true
    log "pm2 インストール完了"
  fi
else
  warn "npm が見つかりません。nodenv で Node をインストール後に npm install -g pm2 を実行してください"
fi

# --- 19. GitHub SSH鍵生成 ---
echo ""
echo "--- 19. GitHub SSH鍵 ---"
SSH_KEY="$HOME/.ssh/id_ed25519"
if [ -f "$SSH_KEY" ]; then
  log "SSH鍵 既に存在"
else
  mkdir -p "$HOME/.ssh"
  ssh-keygen -t ed25519 -C "$SERVER_HOSTNAME" -f "$SSH_KEY" -N ""
  log "SSH鍵を生成しました"
fi
echo ""
echo "  📋 以下の公開鍵をGitHubに登録してください:"
echo "  https://github.com/settings/keys"
echo ""
cat "${SSH_KEY}.pub"
echo ""

# --- 20. zsh設定 ---
echo ""
echo "--- 20. zsh設定 ---"
ZSHRC="$HOME/.zshrc"
touch "$ZSHRC"

# Homebrew
if ! grep -q 'brew shellenv' "$ZSHRC" 2>/dev/null; then
  echo '# Homebrew' >> "$ZSHRC"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$ZSHRC"
fi

# nodenv
if ! grep -q 'nodenv init' "$ZSHRC" 2>/dev/null; then
  echo '# nodenv' >> "$ZSHRC"
  echo 'eval "$(nodenv init -)"' >> "$ZSHRC"
fi

# エイリアス
if ! grep -q '# Server aliases' "$ZSHRC" 2>/dev/null; then
  cat >> "$ZSHRC" << 'ZSHEOF'

# Prompt (カラー + git branch + ディレクトリ)
autoload -Uz vcs_info
precmd() { vcs_info }
zstyle ':vcs_info:git:*' formats ' (%F{cyan}%b%f)'
setopt PROMPT_SUBST
PROMPT='%F{green}%n@%m%f %F{blue}%~%f${vcs_info_msg_0_} %F{yellow}❯%f '

# 補完
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# 色付きls
export CLICOLOR=1
export LSCOLORS=GxFxCxDxBxegedabagaced

# 履歴
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS

# Server aliases
alias ll='ls -la'
alias gs='git status'
alias gp='git push'
alias gl='git pull'
alias pm2l='pm2 list'
alias pm2log='pm2 logs'
ZSHEOF
fi

log "zsh設定完了 (~/.zshrc)"

# --- 21. caffeinate 自動起動 ---
echo ""
echo "--- 21. caffeinate (スリープ防止バックアップ) ---"
PLIST="$HOME/Library/LaunchAgents/com.server.caffeinate.plist"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" << 'CAFFEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.server.caffeinate</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/caffeinate</string>
        <string>-dimsu</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
CAFFEOF
launchctl load "$PLIST" 2>/dev/null || true
log "caffeinate -dimsu ログイン時自動起動を設定"

USEREOF

# ============================================
# 完了
# ============================================
echo ""
echo "========================================="
echo " 🎉 キッティング完了！"
echo "========================================="
echo ""
echo " ホスト名: $SERVER_HOSTNAME"
echo " SSH: ssh $ACTUAL_USER@$SERVER_HOSTNAME.local"
echo ""
echo " 📋 手動確認が必要な項目:"
echo "  1. GitHub に SSH公開鍵を登録 (上に表示済み)"
echo "  2. システム設定 > 一般 > 共有 > 画面共有 を確認"
echo "  3. Tailscale アプリを起動してログイン"
echo "  4. Docker Desktop を起動"
echo "  5. Slack / Discord にログイン"
echo "  6. 自動ログインの確認（システム設定 > ユーザとグループ）"
echo ""
echo " 次のステップ: bash setup-openclaw.sh"
echo ""
echo " 💡 再起動を推奨: sudo reboot"
echo "========================================="
