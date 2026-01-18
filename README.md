# 志望校支払いアドバイザー

大学入試における入学金・授業料の最適支払い戦略を、**Lean4による定理証明**で正当性を保証しながら提示するWindowsデスクトップアプリケーションです。

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

### 📋 定理証明で保証されていること

以下の性質がLean4の定理として証明済みです（`sorry`なし）：

| 優先度 | 保証内容 | 定理名 |
|:---:|--------|--------|
| 🔴 | **期限日には必ず支払い推奨が出る**<br>入学金・授業料ともに、期限当日には必ず何らかの支払いが推奨される | `deadline_forces_payment`<br>`tuition_deadline_forces_payment` |
| 🔴 | **支払い可能な合格校は見逃さない**<br>入学金期限内の合格校があれば、その期限日に必ず推奨が出る | `highest_viable_unpaid_recommended_on_deadline`<br>`tuition_payment_not_missed` |
| 🟡 | **不要な入学金を払わない**<br>上位校に入学可能な合格がある場合、下位校の入学金は推奨されない | `recommendation_avoids_unnecessary_payment` |
| 🟡 | **第1志望合格なら即座に推奨**<br>最上位校に合格したら、待機せず支払いを推奨 | `first_choice_immediate_payment` |
| 🟡 | **入学金は授業料より先**<br>授業料支払いには入学金支払い済みが必須 | `enrollment_before_tuition` |
| 🟢 | **推奨は常に実行可能**<br>推奨された支払いは、必ず支払い可能な状態である | `shouldPayEnrollmentFee_implies_canPay`<br>`shouldPayTuition_implies_canPay` |
| 🟢 | **アクション適用後も整合性を維持**<br>支払い実行後も、学校情報・合格状態は保存される | `applyRecommendedAction_*_preserves_*` |

> 🔴 致命的なミスを防ぐ / 🟡 最適性を保証 / 🟢 システムの健全性を保証

<details>
<summary>詳細: 形式検証の仕組み</summary>

#### 保証の仕組み

```
フロントエンド (JSON入力)
    ↓
Lean4バックエンド
    ├─ 入力バリデーション（型制約の検証）
    │   ├─ 違反 → エラーメッセージを返す
    │   │   例: "授業料は入学金より高くなければなりません"
    │   │
    │   └─ OK → 証明付き型を構築
    │
    ↓
定理証明済みロジック
    │
    └─ 正しい結果を返す ← ここが数学的に保証されている
```

**ポイント**: フロントエンドからのJSONデータは、まずLean4の型制約で検証されます。検証を通過したデータに対しては、定理により正しい結果が保証されます。

#### 例1: 不正なデータを型レベルで排除

```lean
-- 金額は必ず正の値（0円以下は構築不可能）
structure Amount where
  value : Nat
  positive : value > 0  -- ← この証明がないと構築できない
```

フロントエンドから「入学金0円」のようなデータが来ても、バリデーション時に**エラーとして拒否**されます。

#### 例2: ビジネスルールの不変条件を型に埋め込む

```lean
-- 支払い状態: 授業料を払うには入学金が必要
structure PaymentStatus where
  enrollmentFeePaid : Bool
  tuitionPaid : Bool
  -- ↓ この制約により「入学金未払いで授業料だけ払う」状態は構築不可能
  tuitionRequiresEnrollment : tuitionPaid = true → enrollmentFeePaid = true
```

もし不正な入力（`enrollmentFeePaid=false, tuitionPaid=true`）が来た場合、システムは安全な状態（`tuitionPaid=false`に補正）にフォールバックします。

#### 例3: 定理の連鎖による安全性保証

Leanの真価は、複数の定理を組み合わせて**システム全体の安全性**を証明できることです。

```lean
-- 定理1: 期限日には必ず支払いが推奨される
theorem deadline_forces_payment
    (h_can_pay : canPayEnrollmentFee target today = true)
    (h_deadline : today.day = target.school.enrollmentFeeDeadline.day)
    (h_no_higher_viable : ...)
    : shouldPayEnrollmentFee states target today = true := by ...

-- 定理2: 推奨された支払いは正しく状態に反映される
theorem applyRecommendedAction_enrollmentFee_correct
    (h_mem : s ∈ applyRecommendedAction states (.PayEnrollmentFee schoolId))
    (h_id : s.school.id = schoolId)
    : s.paymentStatus.enrollmentFeePaid = true := by ...

-- 定理3: 期限内なら合格は維持される
theorem pass_maintained_within_deadline
    (h_pass : isActivePass state = true)
    (h_within : today.day ≤ state.school.enrollmentFeeDeadline.day)
    : (updateStatusOnDeadline state today).passStatus = PassStatus.Passed ∨ ... := by ...
```

**これらの定理が連鎖して保証すること:**

```
1. deadline_forces_payment
   → 期限日には支払い推奨が必ず出る

2. applyRecommendedAction_enrollmentFee_correct
   → 推奨に従えば支払いが正しく記録される

3. pass_maintained_within_deadline
   → 支払い済みなら合格取り消しにならない
```

つまり、**「推奨に従っていれば合格取り消しにならない」** ことが数学的に証明されています。

これはテストでは不可能な保証です。テストは有限個のケースしか確認できませんが、定理証明は**無限の入力パターン全て**に対して成り立つことを保証します。

</details>

## アーキテクチャ

```
┌──────────────────────────────────────────────────────────┐
│                  Tauri Desktop App                       │
│  ┌─────────────────┐      ┌──────────────────────────┐  │
│  │  React Frontend │      │     Rust Backend         │  │
│  │  (TypeScript)   │ IPC  │     (Tauri v2)           │  │
│  │                 │ ───► │                          │  │
│  │  - カレンダー   │      │  - プロセス管理          │  │
│  │  - 学校カード   │      │  - ファイルI/O           │  │
│  │  - 推奨表示     │      │  - Lean REPL通信         │  │
│  └─────────────────┘      └────────────┬─────────────┘  │
│                                        │ stdio/JSON-RPC │
│                           ┌────────────▼─────────────┐  │
│                           │      Lean4 REPL          │  │
│                           │    (定理証明済みロジック)  │  │
│                           │                          │  │
│                           │  - 支払い判断アルゴリズム │  │
│                           │  - 型による入力検証       │  │
│                           │  - 数学的正当性の証明     │  │
│                           └──────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

| レイヤー | 技術 | 役割 |
|---------|------|------|
| **UI** | React + TypeScript + Tailwind CSS | ユーザーインターフェース |
| **デスクトップ** | Tauri v2 + Rust | ネイティブアプリ化、プロセス管理 |
| **ロジック** | Lean4 | 定理証明済み支払い判断 |

## インストール（Windows）

### ダウンロード

[Releases](https://github.com/jl1nie/school-payment/releases) から最新版をダウンロード：

| ファイル | 説明 |
|---------|------|
| `school-payment_x.x.x_x64-setup.exe` | インストーラー（推奨） |
| `school-payment_x.x.x_x64_en-US.msi` | MSIインストーラー |

### インストール手順

1. ダウンロードした `.exe` または `.msi` を実行
2. インストールウィザードに従ってインストール
3. スタートメニューまたはデスクトップから「志望校支払いアドバイザー」を起動

> **注意**: 初回起動時に Windows Defender SmartScreen の警告が表示される場合があります。「詳細情報」→「実行」をクリックしてください。

## 使い方

### 1. 学校を登録する

- 「**+ 学校を追加**」カードをクリック
- 以下の情報を入力：
  - 大学名、志望順位
  - 受験日、発表日
  - 入学金納付期限、授業料納付期限
  - 入学金、授業料（円）
- 「**追加**」ボタンで保存

> **ヒント**: 「📝 サンプル」ボタンで東大・早稲田・慶應・明治・理科大の2026年度データを読み込めます

### 2. 日付を選択してシミュレーション

- カレンダーで任意の日付をクリック
- 選択した日付から**1週間分の推奨アクション**が自動計算されます
- 日付を変えることで「もし○月○日だったら」というシミュレーションが可能

### 3. 合格状況を更新

- 各学校カードの「**未発表 / 合格 / 不合格**」ボタンで状態を切り替え
- 合格後は入学金・授業料の支払いチェックボックスが有効になります

### 4. 推奨アクションを確認

- 画面上部に1週間分の推奨アクションが日別に表示
- 色分けで緊急度を表示：
  - 🔴 **赤**: 本日期限（要即対応）
  - 🟡 **黄**: 3日以内に期限
  - ⚪ **白**: 余裕あり

### 5. データの保存・読み込み

- 「**📤 エクスポート**」: JSONファイルとして保存
- 「**📥 インポート**」: 保存したJSONファイルを読み込み
- データは自動的にローカルに保存されます

## 支払い判断ロジック

### 入学金を払うべき条件

1. 合格している
2. 入学金未払い
3. 期限内
4. 上位校に「入学可能な合格」がない
   - 入学可能 = 合格 AND (入学金払い済み OR 入学金期限内)
5. 以下のいずれか:
   - 上位校がない（第1志望に合格）
   - 今日が期限日（これ以上待てない）
   - 上位校が全て消滅（不合格/取消/入学金期限切れ）

### 例: 最適戦略

| 状況 | 推奨 |
|------|------|
| 東大(1位)のみ合格 | 東大の入学金を払う（第1志望なので即決） |
| 東大(1位)合格、早稲田(2位)期限当日 | 東大の入学金を払う |
| 東大(1位)不合格、早稲田(2位)期限当日 | 早稲田の入学金を払う |
| 東大(1位)未発表、早稲田(2位)期限当日 | 早稲田の入学金を払う（期限のため） |
| 東大(1位)未発表、早稲田(2位)期限まであと5日 | 何もしない（東大の結果待ち） |

## 開発者向け

<details>
<summary>開発環境のセットアップ</summary>

### 前提条件

- [elan](https://github.com/leanprover/elan)（Lean4バージョン管理）
- [Rust](https://rustup.rs/)（Tauriビルド用）
- Node.js 20+

### セットアップ

```bash
git clone https://github.com/jl1nie/school-payment.git
cd school-payment

# Leanバックエンドをビルド
cd lean-backend && lake build && cd ..

# フロントエンドの依存関係をインストール
cd frontend && npm install && cd ..
```

### 開発モードで起動

```bash
cd frontend && npm run tauri dev
```

### プロダクションビルド（インストーラー生成）

```bash
cd src-tauri && npx tauri build
```

生成物:
- `target/release/bundle/nsis/school-payment_x.x.x_x64-setup.exe`
- `target/release/bundle/msi/school-payment_x.x.x_x64_en-US.msi`

</details>

## 免責事項

本ソフトウェアは**教育・研究目的**で作成されたデモンストレーションです。

- 本ソフトウェアの利用により生じた**いかなる損害**（合格取り消し、不要な支払い、その他の金銭的損失を含む）についても、作者は一切の責任を負いません
- 実際の入学金・授業料の支払い判断は、必ず**各大学の公式情報**を確認し、**ご自身の責任**で行ってください
- 本ソフトウェアが提示する推奨アクションは、あくまで参考情報です
- 支払い期限や金額は大学により異なり、年度によって変更される可能性があります

**重要な支払い判断は、必ず大学の入試課や事務局に直接確認してください。**

## ライセンス

MIT
