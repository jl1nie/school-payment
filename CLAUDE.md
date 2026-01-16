# 志望校支払いアドバイザー

## プロジェクト概要

大学入試における入学金・授業料の最適支払い戦略を、Lean4による定理証明で正当性を保証しながら提示するシステム。

**重要**: このシステムはバグが許されない。支払い判断の誤りは合格取り消しや不要な出費につながるため、全てのビジネスロジックはLean4で形式検証されている。

## アーキテクチャ

```
┌─────────────────┐     JSON-RPC      ┌─────────────────┐
│  React Frontend │ ◄──────────────► │  Lean4 REPL     │
│  (TypeScript)   │                   │  Backend        │
└─────────────────┘                   └─────────────────┘
        │                                     │
        │                                     │
        ▼                                     ▼
   ユーザー入力                         定理証明済み
   - 志望校情報                         ビジネスロジック
   - 合格状況
   - 現在日付
```

### バックエンド (Lean4 REPL)

- **場所**: `/backend`
- **技術**: Lean4 + lake
- **役割**: 
  - 支払い判断ロジック（定理証明済み）
  - JSON-RPCでフロントエンドと通信
  - 全ての計算結果に証明が付随

### フロントエンド (React)

- **場所**: `/frontend`
- **技術**: React + TypeScript + Vite
- **役割**:
  - 志望校情報の入力UI
  - 合格状況の管理
  - 推奨アクションの表示
  - タイムライン表示

## ビジネスルール（絶対に変更不可）

以下のルールはLean4で証明済み。実装を変更する場合は必ず証明も更新すること。

### 1. 支払い順序の制約
```
授業料支払い → 入学金支払い済みが前提条件
```
**証明**: `tuition_requires_enrollment_fee`

### 2. 期限の制約
```
入学金期限 < 今日 ∧ 未払い → 合格取り消し
授業料期限 < 今日 ∧ 未払い → 合格取り消し
```
**証明**: `updateStatusOnDeadline`

### 3. 最適戦略
```
より希望順位の高い学校の結果待ち中 → 支払いを遅延
期限当日 → 必ず支払い
全上位校が消滅 → 支払い実行
```
**証明**: `deadline_forces_payment`, `waiting_can_save_money`

### 4. 金額の制約
```
授業料 > 入学金（全ての学校で）
```
**証明**: `School`構造体の`tuitionHigherThanFee`フィールド

## データ構造

### School（学校情報）
```lean
structure School where
  id : Nat
  name : String
  priority : Priority           -- 希望順位（1が最高）
  examDate : Date              -- 受験日
  resultDate : Date            -- 発表日
  enrollmentFeeDeadline : Date -- 入学金期限
  tuitionDeadline : Date       -- 授業料期限
  enrollmentFee : Amount       -- 入学金
  tuition : Amount             -- 授業料
  -- 以下は証明済み制約
  tuitionHigherThanFee : tuition.value > enrollmentFee.value
  resultAfterExam : resultDate.day ≥ examDate.day
  feeDeadlineAfterResult : enrollmentFeeDeadline.day ≥ resultDate.day
  tuitionAfterFee : tuitionDeadline.day ≥ enrollmentFeeDeadline.day
```

### SchoolState（学校の状態）
```lean
structure SchoolState where
  school : School
  passStatus : PassStatus      -- NotYetAnnounced | Passed | Failed | Cancelled
  paymentStatus : PaymentStatus -- enrollmentFeePaid, tuitionPaid
```

### PaymentAction（支払いアクション）
```lean
inductive PaymentAction
  | PayEnrollmentFee (schoolId : Nat)
  | PayTuition (schoolId : Nat)
  | DoNothing
```

## API設計（JSON-RPC）

### リクエスト形式
```json
{
  "jsonrpc": "2.0",
  "method": "getRecommendation",
  "params": {
    "today": 28,
    "schools": [
      {
        "id": 1,
        "name": "東京大学",
        "priority": 1,
        "examDate": 25,
        "resultDate": 40,
        "enrollmentFeeDeadline": 45,
        "tuitionDeadline": 60,
        "enrollmentFee": 282000,
        "tuition": 535800
      }
    ],
    "states": [
      {
        "schoolId": 1,
        "passStatus": "notYetAnnounced",
        "enrollmentFeePaid": false,
        "tuitionPaid": false
      }
    ]
  },
  "id": 1
}
```

### レスポンス形式
```json
{
  "jsonrpc": "2.0",
  "result": {
    "action": {
      "type": "payEnrollmentFee",
      "schoolId": 3
    },
    "reason": "本日が明治大学の入学金支払期限です。",
    "urgency": 0,
    "allRecommendations": [...]
  },
  "id": 1
}
```

## 開発ガイドライン

### Lean4コードの変更時

1. **証明を壊さないこと**
   - `sorry`を残さない
   - 全ての定理が証明完了していることを確認
   - `lake build`でエラーがないこと

2. **新しいビジネスルールの追加**
   - 必ず対応する定理を追加
   - 既存の証明との整合性を確認

3. **テスト**
   ```bash
   cd lean-backend
   lake build
   lake exe advisor  # サンプル実行
   ```

### Reactコードの変更時

1. **型安全性**
   - Lean側の型定義と一致させる
   - `zod`でランタイムバリデーション

2. **エラーハンドリング**
   - Lean REPLからのエラーを適切に表示
   - ネットワークエラーのリトライ

### コミット前チェックリスト

- [ ] `lake build`が成功する
- [ ] 全ての`sorry`が解消されている
- [ ] フロントエンドの型がバックエンドと一致
- [ ] エッジケースのテスト（期限当日、全校不合格など）

## ディレクトリ構造

```
/
├── CLAUDE.md                    # このファイル
├── README.md                    # プロジェクト概要
│
├── lean-backend/                # Lean4バックエンド（定理証明）
│   ├── lakefile.lean            # Lakeビルド設定
│   ├── lean-toolchain           # Lean4バージョン (v4.14.0)
│   ├── Main.lean                # REPLサーバーエントリポイント
│   └── src/
│       ├── SchoolPayment.lean   # ライブラリエントリ
│       └── SchoolPayment/
│           ├── Types.lean       # 基本型定義（証明付き制約）
│           ├── Rules.lean       # ビジネスルールと定理
│           ├── Strategy.lean    # 最適戦略アルゴリズムと証明
│           ├── Json.lean        # JSONシリアライズ
│           └── Repl.lean        # REPL通信処理
│
├── api-server/                  # Node.js APIサーバー（プロキシ）
│   ├── package.json
│   ├── tsconfig.json
│   └── src/
│       └── index.ts             # Express + Lean REPL連携
│
└── frontend/                    # Reactフロントエンド
    ├── package.json
    ├── vite.config.ts
    ├── tailwind.config.js
    ├── index.html
    └── src/
        ├── App.tsx              # メインアプリケーション
        ├── components/          # UIコンポーネント
        ├── hooks/               # カスタムフック
        └── types/               # TypeScript型定義
```

## 重要な定理一覧

| 定理名 | 内容 | ファイル |
|--------|------|----------|
| `tuition_requires_enrollment_fee` | 授業料支払いには入学金支払いが必要 | Rules.lean |
| `deadline_forces_payment` | 期限日には必ず支払いが推奨される | Strategy.lean |
| `enrollment_before_tuition` | 入学金は常に授業料より先 | Strategy.lean |
| `recommendation_is_valid` | 推奨される支払いは常に有効 | Strategy.lean |
| `waiting_can_save_money` | 待つことで費用節約の可能性 | Rules.lean |

## よくある実装ミス

### ❌ 避けるべきパターン

```typescript
// フロントエンドで支払い判断をしない！
if (today >= deadline) {
  recommend("pay");  // NG: Lean側で判断すべき
}
```

### ✅ 正しいパターン

```typescript
// 常にLean REPLに問い合わせる
const recommendation = await leanRepl.getRecommendation(today, schools, states);
```

## 環境構築

### バックエンド (Lean4)
```bash
# elanインストール（初回のみ）
curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh

# ビルド
cd lean-backend
lake update
lake build

# REPLサーバー起動
lake exe advisor
```

### APIサーバー (Node.js)
```bash
cd api-server
npm install
npm run dev
```

### フロントエンド (React)
```bash
cd frontend
npm install
npm run dev
```

### 統合実行（3ターミナル必要）
```bash
# ターミナル1: Lean REPLサーバー
cd lean-backend && lake exe advisor --repl

# ターミナル2: APIサーバー（ポート3001）
cd api-server && npm run dev

# ターミナル3: フロントエンド（ポート5173）
cd frontend && npm run dev
```

## テストシナリオ

### シナリオ1: 期限当日の判断
- Day 28（明治の入学金期限）
- 明治: 合格、未払い
- 早稲田: 合格、未払い
- 東大: 未発表
- **期待結果**: 明治の入学金を払う（期限のため）

### シナリオ2: 上位校確定後
- Day 45（東大の入学金期限）
- 東大: 合格、未払い
- 早稲田: 合格、入学金済み
- 明治: 合格、入学金済み
- **期待結果**: 東大の入学金を払う（最上位のため）

### シナリオ3: 待機推奨
- Day 30
- 東大: 未発表
- 早稲田: 合格、未払い（期限: Day 35）
- **期待結果**: 何もしない（東大の結果待ち）

## 注意事項

1. **日付は整数日数で管理**
   - 2月1日を基準(Day 1)として計算
   - フロントエンドで実日付に変換

2. **金額は整数（円単位）**
   - 小数点以下は扱わない

3. **証明の`sorry`は絶対に残さない**
   - 本番環境では全ての証明が完了していること
   - CIで`sorry`の有無をチェック
