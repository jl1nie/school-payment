# 志望校支払いアドバイザー

大学入試における入学金・授業料の最適支払い戦略を、**Lean4による定理証明**で正当性を保証しながら提示するシステムです。

![スクリーンショット](docs/images/screenshot.png)

## 特徴

### バグが許されない支払い判断を形式検証で保証

大学入試の入学金支払いは、一歩間違えると：
- **合格取り消し**（期限を過ぎて未払い）
- **無駄な出費**（上位校に合格しているのに下位校に払ってしまう）

という取り返しのつかない結果を招きます。

本システムでは、支払い判断ロジックを**Lean4で形式検証**することで、これらのミスを**数学的に排除**しています。

### なぜLean4を使うのか？

通常のプログラミングでは、テストでバグを見つけますが、**全てのケースをテストすることは不可能**です。

Lean4では、コードに対する**数学的証明**を書くことで、**あらゆる入力に対して正しく動作すること**を保証できます。

#### 例1: 不正なデータを型レベルで排除

```lean
-- 金額は必ず正の値（0円以下は構築不可能）
structure Amount where
  value : Nat
  positive : value > 0  -- ← この証明がないと構築できない
```

「入学金0円」のような不正データは、**コンパイル時点でエラー**になります。

#### 例2: ビジネスルールの不変条件を型に埋め込む

```lean
-- 支払い状態: 授業料を払うには入学金が必要
structure PaymentStatus where
  enrollmentFeePaid : Bool
  tuitionPaid : Bool
  -- ↓ この証明により「入学金未払いで授業料だけ払う」状態は構築不可能
  tuitionRequiresEnrollment : tuitionPaid = true → enrollmentFeePaid = true
```

#### 例3: 期限日には必ず支払い推奨される定理

```lean
/-- 期限日で上位校に入学可能な合格がなければ、支払いが推奨される -/
theorem deadline_forces_payment
    (states : List SchoolState)
    (target : SchoolState)
    (today : Date)
    (h_can_pay : canPayEnrollmentFee target today = true)
    (h_deadline : today.day = target.school.enrollmentFeeDeadline.day)
    (h_no_higher_viable : ...) :
    shouldPayEnrollmentFee states target today = true := by
  -- 証明（省略）
```

この定理により、**期限日に支払い推奨を出し忘れることがないこと**が数学的に保証されます。

## アーキテクチャ

```
┌─────────────────┐     JSON-RPC      ┌─────────────────┐
│  React Frontend │ ◄──────────────► │  Node.js API    │
│  (TypeScript)   │                   │  Server         │
└─────────────────┘                   └────────┬────────┘
                                               │ stdio
                                               ▼
                                      ┌─────────────────┐
                                      │  Lean4 REPL     │
                                      │  (定理証明済み)  │
                                      └─────────────────┘
```

- **フロントエンド**: React + TypeScript（UI表示）
- **APIサーバー**: Node.js（JSON-RPC通信のプロキシ）
- **バックエンド**: Lean4（支払い判断ロジック + 定理証明）

## インストール

### 前提条件

- [elan](https://github.com/leanprover/elan)（Lean4バージョン管理）
- Node.js 18+
- [cargo-make](https://github.com/sagiegurari/cargo-make)（タスクランナー）

### セットアップ

```bash
# リポジトリをクローン
git clone https://github.com/jl1nie/school-payment.git
cd school-payment

# 依存関係をインストール
makers install
```

## 実行方法

### 開発サーバーの起動

```bash
# 全サービスを並列起動（推奨）
makers dev
```

ブラウザで http://localhost:5173 を開きます。

### 個別起動

```bash
# フロントエンドのみ
makers dev-front

# APIサーバーのみ
makers dev-api

# Lean REPLのみ
makers dev-lean
```

### ビルド

```bash
# 全プロジェクトをビルド
makers build

# Leanのみビルド（証明の検証）
makers build-lean
```

### 利用可能なタスク一覧

```bash
makers
```

## 使い方

1. **サンプルデータを読み込む**
   - 「サンプル」ボタンをクリック（東大・早稲田・慶應・理科大の2025年度データ）

2. **日付を設定する**
   - カレンダーで任意の日付をクリック

3. **推奨アクションを取得**
   - 「1週間の推奨アクションを取得」ボタンをクリック

4. **合格状況を更新**
   - 各学校のカードで合格/不合格/取消を設定
   - 入学金・授業料の支払い状況もチェックボックスで管理

## 支払い判断ロジック

### 入学金を払うべき条件

1. 合格している
2. 入学金未払い
3. 期限内
4. 上位校に「入学可能な合格」がない
   - 入学可能 = 合格 AND (入学金払い済み OR 入学金期限内)
5. 以下のいずれか:
   - 今日が期限日（これ以上待てない）
   - 上位校が全て消滅（不合格/取消/入学確定/入学金期限切れ）

### 例: 最適戦略

| 状況 | 推奨 |
|------|------|
| 東大(1位)合格、早稲田(2位)期限当日 | 何もしない（東大に払えば良い） |
| 東大(1位)入学金期限切れ、早稲田(2位)期限当日 | 早稲田の入学金を払う |
| 東大(1位)のみ合格、期限まであと5日 | 何もしない（期限まで待つ） |
| 東大(1位)のみ合格、期限当日 | 東大の入学金を払う |

## ライセンス

MIT
