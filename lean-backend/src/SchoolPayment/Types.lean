/-
  SchoolPayment/Types.lean

  志望校支払い最適化問題の基本型定義

  このファイルは形式検証の基盤となる型を定義する。
  各型には不変条件（invariant）が証明として埋め込まれており、
  これにより不正な状態の構築を型レベルで防止する。

  【設計思想】
  - 依存型を活用し、ビジネスルールを型制約として表現
  - 不正な値の構築を静的に防止
  - 証明付き制約により、ランタイムエラーを排除
-/

namespace SchoolPayment

/-! ## 基本データ型 -/

/--
  日付を表す型（YYYYMMDD形式の整数）

  例: 2025年2月1日 = 20250201, 2025年3月10日 = 20250310
  整数の大小比較がそのまま日付の前後関係となる。
-/
structure Date where
  day : Nat  -- YYYYMMDD形式（例: 20250201）
deriving Repr, DecidableEq, Inhabited

/-! ### Date の順序関係 -/

instance : LE Date where
  le d1 d2 := d1.day ≤ d2.day

instance : LT Date where
  lt d1 d2 := d1.day < d2.day

instance : Ord Date where
  compare d1 d2 := compare d1.day d2.day

instance (d1 d2 : Date) : Decidable (d1 ≤ d2) :=
  inferInstanceAs (Decidable (d1.day ≤ d2.day))

instance (d1 d2 : Date) : Decidable (d1 < d2) :=
  inferInstanceAs (Decidable (d1.day < d2.day))

/-! ### Date のYYYYMMDD形式での日付演算 -/

/-- うるう年判定 -/
def isLeapYear (year : Nat) : Bool :=
  (year % 4 == 0 && year % 100 != 0) || year % 400 == 0

/-- 各月の日数を取得（うるう年対応） -/
def daysInMonth (year month : Nat) : Nat :=
  match month with
  | 1 => 31
  | 2 => if isLeapYear year then 29 else 28
  | 3 => 31  | 4 => 30  | 5 => 31  | 6 => 30
  | 7 => 31  | 8 => 31  | 9 => 30  | 10 => 31
  | 11 => 30 | 12 => 31
  | _ => 30

/-- その年の1月1日から指定月の1日までの日数 -/
def daysBeforeMonth (year month : Nat) : Nat :=
  let rec go (m : Nat) (acc : Nat) : Nat :=
    if m >= month then acc
    else go (m + 1) (acc + daysInMonth year m)
  go 1 0

/-- YYYYMMDD形式の日付に1日加算 -/
def Date.addOneDay (d : Date) : Date :=
  let year := d.day / 10000
  let month := (d.day / 100) % 100
  let day := d.day % 100
  let maxDay := daysInMonth year month
  if day < maxDay then
    ⟨year * 10000 + month * 100 + (day + 1)⟩
  else if month < 12 then
    ⟨year * 10000 + (month + 1) * 100 + 1⟩
  else
    ⟨(year + 1) * 10000 + 1 * 100 + 1⟩

/-- YYYYMMDD形式の日付にn日加算 -/
def Date.addDays (d : Date) (n : Nat) : Date :=
  match n with
  | 0 => d
  | n + 1 => (d.addOneDay).addDays n

/--
  金額を表す型（正の整数のみ許容）

  【証明付き制約】
  - `positive` フィールドにより、0円以下の金額は型レベルで構築不可
  - これにより「入学金0円」のような不正データを静的に排除
-/
structure Amount where
  value : Nat
  positive : value > 0 := by decide
deriving Repr

/-! ### Amount の順序関係と演算 -/

instance : LE Amount where
  le a1 a2 := a1.value ≤ a2.value

instance : LT Amount where
  lt a1 a2 := a1.value < a2.value

instance (a1 a2 : Amount) : Decidable (a1 ≤ a2) :=
  inferInstanceAs (Decidable (a1.value ≤ a2.value))

instance (a1 a2 : Amount) : Decidable (a1 < a2) :=
  inferInstanceAs (Decidable (a1.value < a2.value))

/-- 金額の加算（正値性を保存） -/
def Amount.add (a1 a2 : Amount) : Amount :=
  ⟨a1.value + a2.value, Nat.add_pos_left a1.positive a2.value⟩

instance : Add Amount where
  add := Amount.add

/--
  希望順位（1が最も希望順位が高い）

  【証明付き制約】
  - `valid` により rank > 0 が保証される
  - priority 1 が第一志望、2 が第二志望...
-/
structure Priority where
  rank : Nat
  valid : rank > 0 := by decide
deriving Repr, DecidableEq

/--
  優先度比較：数字が小さいほど優先度が高い

  例: Priority 1 は Priority 2 より higherThan
-/
def Priority.higherThan (p1 p2 : Priority) : Bool := p1.rank < p2.rank

instance : LT Priority where
  lt p1 p2 := p1.rank < p2.rank

instance (p1 p2 : Priority) : Decidable (p1 < p2) :=
  inferInstanceAs (Decidable (p1.rank < p2.rank))

/-! ## ドメインモデル -/

/--
  学校情報を表す構造体

  【証明付き制約（4つの不変条件）】
  1. `tuitionHigherThanFee`: 授業料 > 入学金（問題の前提条件）
  2. `resultAfterExam`: 発表日 ≥ 受験日
  3. `feeDeadlineAfterResult`: 入学金期限 ≥ 発表日
  4. `tuitionAfterFee`: 授業料期限 ≥ 入学金期限

  これらの制約は School 構築時に証明が要求され、
  不整合なデータ（発表前に期限が来る等）を型レベルで排除する。
-/
structure School where
  id : Nat
  name : String
  priority : Priority             -- 希望順位
  examDate : Date                 -- 受験日
  resultDate : Date               -- 発表日
  enrollmentFeeDeadline : Date    -- 入学金支払期限
  tuitionDeadline : Date          -- 授業料支払期限
  enrollmentFee : Amount          -- 入学金
  tuition : Amount                -- 授業料
  -- 【証明付き制約】以下は構築時に自動検証される
  tuitionHigherThanFee : tuition.value > enrollmentFee.value
  resultAfterExam : resultDate.day ≥ examDate.day
  feeDeadlineAfterResult : enrollmentFeeDeadline.day ≥ resultDate.day
  tuitionAfterFee : tuitionDeadline.day ≥ enrollmentFeeDeadline.day
deriving Repr

/--
  合格状態を表す列挙型

  【状態遷移】
  NotYetAnnounced → Passed | Failed  （発表時）
  Passed → Cancelled                  （期限切れ時）

  一度 Failed/Cancelled になると変更不可
-/
inductive PassStatus
  | NotYetAnnounced  -- まだ発表されていない
  | Passed           -- 合格
  | Failed           -- 不合格
  | Cancelled        -- 合格取り消し（期限切れで入学金/授業料未払い）
deriving Repr, DecidableEq, Inhabited

/--
  支払い状態を表す構造体

  【証明付き制約】
  - `tuitionRequiresEnrollment`: 授業料支払い済み → 入学金支払い済み
  - これにより「入学金未払いで授業料だけ払う」という不正状態を防止

  【証明戦略】
  デフォルト値では `by intro h; cases h; decide` で証明
  これは「tuitionPaid = true を仮定すると矛盾」を示す
-/
structure PaymentStatus where
  enrollmentFeePaid : Bool  -- 入学金支払済み
  tuitionPaid : Bool        -- 授業料支払済み
  tuitionRequiresEnrollment : tuitionPaid = true → enrollmentFeePaid = true := by
    intro h; cases h; decide
deriving Repr

/-! ### PaymentStatus のインスタンス実装 -/

/--
  PaymentStatus の等価性判定

  【証明戦略】
  証明フィールド (`tuitionRequiresEnrollment`) は等価性に影響しないため、
  `enrollmentFeePaid` と `tuitionPaid` のみを比較する。
  証明の同値性は proof irrelevance により保証される。
-/
instance : DecidableEq PaymentStatus :=
  fun p1 p2 =>
    if h1 : p1.enrollmentFeePaid = p2.enrollmentFeePaid then
      if h2 : p1.tuitionPaid = p2.tuitionPaid then
        isTrue (by
          cases p1 with | mk e1 t1 _ =>
          cases p2 with | mk e2 t2 _ =>
          simp at h1 h2
          subst h1 h2
          rfl)
      else isFalse (by intro h; cases h; contradiction)
    else isFalse (by intro h; cases h; contradiction)

/-- デフォルト値: 両方とも未払い -/
instance : Inhabited PaymentStatus :=
  ⟨{ enrollmentFeePaid := false, tuitionPaid := false, tuitionRequiresEnrollment := by intro h; cases h }⟩

/--
  学校の現在の状態を表す構造体

  School（静的情報）と動的な状態（合格・支払い状況）を組み合わせる
-/
structure SchoolState where
  school : School
  passStatus : PassStatus
  paymentStatus : PaymentStatus
deriving Repr

/-! ## アクション型 -/

/--
  支払いアクションの種類

  システムが推奨するアクションを表現する。
  各アクションには対象学校のIDが含まれる（DoNothing以外）
-/
inductive PaymentAction
  | PayEnrollmentFee (schoolId : Nat)  -- 入学金を支払う
  | PayTuition (schoolId : Nat)        -- 授業料を支払う
  | DoNothing                          -- 何もしない（待機）
deriving Repr, DecidableEq

/--
  推奨アクションと理由を表す構造体

  - `action`: 推奨される支払いアクション
  - `reason`: 推奨理由（ユーザー向けメッセージ）
  - `urgency`: 緊急度（期限までの日数、0 = 本日期限で最も緊急）
-/
structure Recommendation where
  action : PaymentAction
  reason : String
  urgency : Nat  -- 0が最も緊急（本日期限）
deriving Repr

end SchoolPayment
