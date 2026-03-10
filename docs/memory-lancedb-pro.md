# memory-lancedb-pro 導入ガイド

OpenClaw のビルトイン記憶（memory-lancedb）を強化するプラグイン。  
ベクトル検索 + キーワード検索のハイブリッドで、100件以上の記憶でも精度が落ちない。

---

## 概要

| 項目 | 内容 |
|------|------|
| リポジトリ | https://github.com/win4r/memory-lancedb-pro |
| ライセンス | MIT（無料） |
| 依存 | `@lancedb/lancedb`, `openai`, `@sinclair/typebox` |
| DB保存先 | `~/.openclaw/memory/lancedb-pro/`（ローカルファイル） |
| 外部API | Jina AI（embedding + reranking） |

### ビルトイン版との違い

- **ハイブリッド検索**: ベクトル（意味的類似度）+ BM25（キーワード一致）の両方で検索
- **Cross-Encoder Rerank**: 検索結果を Jina Reranker で再評価・並び替え
- **マルチスコープ**: `global`（全bot共有）/ `agent:<id>`（bot専用）で記憶を分離
- **ノイズフィルタ**: 挨拶・HEARTBEAT・メタ質問を自動除外
- **MMR多様性**: 重複する検索結果を排除
- **時間減衰**: 古い記憶の優先度を自然に下げる（消えはしない）
- **管理CLI**: `openclaw memory-pro list/search/stats/delete/export/import`

---

## 前提条件

- OpenClaw 2026.3.2 以降
- Jina API キー（https://jina.ai/ で無料取得、月100万トークン無料枠）

### Jina トークン消費の目安

| 操作 | 消費量 |
|------|--------|
| 記憶1件の embedding | 約50〜200トークン |
| memory_recall 1回（rerank込み） | 約2,000トークン |
| auto-recall（毎メッセージ自動検索） | 1日100メッセージで約20〜30万トークン |

無料枠（100万/月）を超えた場合: $0.02/100万トークン（月額 $0.1〜0.2 程度）。

---

## インストール手順

### 1. プラグインを clone

```bash
mkdir -p ~/.openclaw/workspace/plugins
cd ~/.openclaw/workspace/plugins
git clone https://github.com/win4r/memory-lancedb-pro.git
cd memory-lancedb-pro
npm install
```

### 2. セキュリティ確認（推奨）

導入前にマルウェアチェックを実施すること：

```bash
# 外部通信の確認（設定したAPI以外のURLがないか）
grep -rn "https\?://" src/ index.ts --include="*.ts"

# exec/spawn の確認
grep -rn "child_process\|execSync\|spawnSync" src/ index.ts --include="*.ts"

# postinstall スクリプトの確認
cat package.json | grep -A5 '"scripts"'
```

### 3. 設定追加

**⚠️ `openclaw config set` のみ使用。JSON直接編集禁止。**

`plugins` 全体を一括で設定する（バリデーションの都合で分割設定不可）：

```bash
openclaw config set plugins '{"load":{"paths":["/Users/dev/.openclaw/workspace/plugins/memory-lancedb-pro"]},"entries":{"discord":{"enabled":true},"slack":{"enabled":true},"memory-lancedb-pro":{"enabled":true,"config":{"embedding":{"apiKey":"<JINA_API_KEY>","model":"jina-embeddings-v5-text-small","baseURL":"https://api.jina.ai/v1","dimensions":1024},"retrieval":{"rerank":"cross-encoder","rerankApiKey":"<JINA_API_KEY>","rerankModel":"jina-reranker-v3","rerankEndpoint":"https://api.jina.ai/v1/rerank"}}}},"slots":{"memory":"memory-lancedb-pro"}}'
```

> **注意**: `<JINA_API_KEY>` を実際のキーに置き換える。  
> **注意**: 既存の `plugins.entries`（discord, slack等）を含めること。上書きで消える。

### 4. Gateway 再起動

```bash
openclaw gateway restart
```

### 5. 動作確認

```bash
# プラグイン一覧に表示されるか
openclaw plugins list

# 記憶の保存テスト
openclaw memory-pro list

# 記憶の検索テスト
openclaw memory-pro search "テスト"
```

エージェントとの会話内で `memory_store` / `memory_recall` ツールが使えれば成功。

---

## 設定オプション

### auto-capture / auto-recall

| 設定 | デフォルト | 説明 |
|------|-----------|------|
| `autoCapture` | `true` | 会話から自動的に記憶を抽出・保存 |
| `autoRecall` | `true` | 毎メッセージで自動的に関連記憶を検索 |
| `autoRecallTopK` | `3` | 自動検索で返す記憶の最大数 |

Jina トークンを節約したい場合、`autoRecall: false` にして手動 recall のみにできる。

### スコープ（マルチbot記憶共有）

```json
"scopes": {
  "default": "global",
  "agentAccess": {
    "main": ["global", "agent:main"],
    "voice-bot": ["global", "agent:voice-bot"]
  }
}
```

- `global`: 全エージェント共有
- `agent:<id>`: そのエージェント専用
- `project:<id>`: プロジェクト単位の共有

### retrieval チューニング

| 設定 | デフォルト | 説明 |
|------|-----------|------|
| `retrieval.mode` | `hybrid` | `hybrid`（推奨）/ `vector`（ベクトルのみ） |
| `retrieval.minScore` | `0.35` | この点数以下の結果を除外 |
| `retrieval.recencyHalfLifeDays` | `14` | 新しい記憶を優遇する半減期 |
| `retrieval.timeDecayHalfLifeDays` | `60` | 古い記憶の減衰半減期 |

---

## CLI リファレンス

```bash
# 記憶一覧
openclaw memory-pro list [--scope global] [--category fact] [--limit 20] [--json]

# 記憶検索
openclaw memory-pro search "クエリ" [--scope global] [--limit 10] [--json]

# 統計
openclaw memory-pro stats [--scope global]

# 記憶削除（ID指定）
openclaw memory-pro delete <id>

# 一括削除
openclaw memory-pro delete-bulk --scope global [--before 2025-01-01] [--dry-run]

# エクスポート / インポート
openclaw memory-pro export [--output memories.json]
openclaw memory-pro import memories.json [--dry-run]

# ビルトイン memory-lancedb からの移行
openclaw memory-pro migrate check
openclaw memory-pro migrate run [--dry-run]
```

---

## Voice Bot 連携（CLI経由）

Voice Bot（独自Node.jsアプリ）から記憶を共有する場合、CLI経由で読み書きする：

```javascript
const { execSync } = require('child_process');

// 記憶を検索（応答生成前）
const result = execSync(
  'openclaw memory-pro search "ユーザーの好み" --limit 3 --json',
  { encoding: 'utf-8' }
);
const memories = JSON.parse(result);

// 記憶を保存（会話後）
execSync(
  `openclaw memory-pro store --text "ユーザーはカレーが好き" --scope global`
);
```

---

## トラブルシューティング

### `plugin not found: memory-lancedb-pro`

`plugins.load.paths` に絶対パスで指定しているか確認：

```bash
openclaw config get plugins.load.paths
# → ["/Users/dev/.openclaw/workspace/plugins/memory-lancedb-pro"] であること
```

### `Missing env var "JINA_API_KEY"`

`${JINA_API_KEY}` 形式ではなく、APIキーを直接記載する。  
LaunchAgent（Gateway）はシェル環境変数を継承しないため。

### config バリデーションエラー

`plugins.load.paths` と `plugins.entries` を分割して設定するとバリデーションエラーになる。  
`plugins` 全体を一括で設定すること（上記手順参照）。

---

## 参考リンク

- リポジトリ: https://github.com/win4r/memory-lancedb-pro
- README（詳細設定）: https://github.com/win4r/memory-lancedb-pro/blob/main/README.md
- 動画チュートリアル: https://youtu.be/MtukF1C8epQ
