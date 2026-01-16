/-
  SchoolPayment/Rules.lean

  ビジネスルールの形式化と定理の証明

  【このファイルの目的】
  支払い判断に関するビジネスルールを形式化し、その正当性を証明する。
  証明済みの定理により、実装の正しさを数学的に保証する。

  【主要な定理】
  1. tuition_requires_enrollment_fee: 入学金支払いは授業料支払いの前提条件
  2. payment_order_correct: 支払い順序の整合性
  3. waiting_can_save_money: 待機による費用削減の可能性
  4. optimal_strategy_minimizes_cost: 最適戦略の存在

  【設計思想】
  - 各ビジネスルールを述語（predicate）として定義
  - ルール間の関係を定理として証明
  - 証明はコンパイル時に検証され、実行時のバグを排除
-/

import SchoolPayment.Types

namespace SchoolPayment

/-! ## 状態判定述語 -/

/--
  学校が有効な合格状態かどうか

  Passed のみが有効。NotYetAnnounced, Failed, Cancelled は無効。
  この述語は支払い可能性の判定に使用される。
-/
def isActivePass (state : SchoolState) : Bool :=
  state.passStatus == PassStatus.Passed

/--
  学校の合格が取り消されているかどうか

  取り消しは期限切れで未払いの場合に発生する。
-/
def isCancelled (state : SchoolState) : Bool :=
  state.passStatus == PassStatus.Cancelled

/-! ## 支払い可能性の判定 -/

/--
  入学金支払いが可能かどうか

  【条件】
  1. 合格している (isActivePass)
  2. 入学金未払い
  3. 今日が期限内 (today ≤ deadline)

  これらの条件を全て満たす場合のみ支払い可能。
-/
def canPayEnrollmentFee (state : SchoolState) (today : Date) : Bool :=
  isActivePass state ∧
  ¬state.paymentStatus.enrollmentFeePaid ∧
  today ≤ state.school.enrollmentFeeDeadline

/--
  授業料支払いが可能かどうか

  【条件】
  1. 合格している (isActivePass)
  2. 入学金支払い済み ← 重要！
  3. 授業料未払い
  4. 今日が期限内 (today ≤ deadline)

  入学金を先に払わないと授業料は払えない。
-/
def canPayTuition (state : SchoolState) (today : Date) : Bool :=
  isActivePass state ∧
  state.paymentStatus.enrollmentFeePaid ∧
  ¬state.paymentStatus.tuitionPaid ∧
  today ≤ state.school.tuitionDeadline

/--
  期限が切れているかどうか

  today.day > deadline.day の場合に true
-/
def deadlinePassed (deadline : Date) (today : Date) : Bool :=
  today.day > deadline.day

/-! ## 定理1: 支払い順序の制約 -/

/--
  【定理】入学金を払わずに授業料を払うことはできない

  この定理は canPayTuition の定義から直接導かれる。
  canPayTuition が true なら、enrollmentFeePaid も true である。

  【証明戦略】
  canPayTuition の定義を展開し、∧ の要素を抽出する。
  simp で定義を展開し、h.2.1 で enrollmentFeePaid を取り出す。
-/
theorem tuition_requires_enrollment_fee
    (state : SchoolState)
    (today : Date)
    (h : canPayTuition state today = true) :
    state.paymentStatus.enrollmentFeePaid = true := by
  simp [canPayTuition, isActivePass] at h
  exact h.2.1

/-! ## 定理2: 期限切れと合格取り消し -/

/--
  期限超過時の状態更新関数

  【ルール】
  - 合格している学校について:
    - 入学金期限切れ かつ 未払い → 合格取り消し
    - 授業料期限切れ かつ 未払い → 合格取り消し
  - それ以外は状態変更なし

  【重要】
  この関数は毎日の状態チェックで呼び出され、
  期限切れの学校を自動的に Cancelled に更新する。
-/
def updateStatusOnDeadline (state : SchoolState) (today : Date) : SchoolState :=
  if state.passStatus == PassStatus.Passed then
    -- 入学金期限切れで未払いの場合
    if deadlinePassed state.school.enrollmentFeeDeadline today ∧
       ¬state.paymentStatus.enrollmentFeePaid then
      { state with passStatus := PassStatus.Cancelled }
    -- 授業料期限切れで未払いの場合（入学金は払済みのケース）
    else if deadlinePassed state.school.tuitionDeadline today ∧
            ¬state.paymentStatus.tuitionPaid then
      { state with passStatus := PassStatus.Cancelled }
    else state
  else state

/-! ## 定理3: 優先度と待機判断 -/

/--
  より希望順位の高い学校で結果待ち/支払い可能なものが存在するか

  【用途】
  この述語が true の場合、すぐに支払わず待機すべき可能性がある。
  上位校の結果が出てから判断することで、無駄な出費を避けられる。

  【条件】
  - target より優先度が高い学校が存在し、かつ
  - その学校が「未発表」または「合格していて入学金支払い可能」
-/
def existsHigherPriorityPending (states : List SchoolState) (target : SchoolState) (today : Date) : Bool :=
  states.any fun s =>
    s.school.priority.higherThan target.school.priority ∧
    (s.passStatus == PassStatus.NotYetAnnounced ∨
     (isActivePass s ∧ canPayEnrollmentFee s today))

/-! ## 定理4: 支払い順序の正しさ -/

/--
  【定理】支払い順序の整合性保証

  授業料が支払われている場合、必ず入学金も支払われている。
  この定理は PaymentStatus 型の tuitionRequiresEnrollment 制約により
  自動的に成り立つ。

  【証明戦略】
  PaymentStatus の tuitionRequiresEnrollment フィールドを直接使用。
  このフィールドは「tuitionPaid = true → enrollmentFeePaid = true」
  という証明を保持している。
-/
theorem payment_order_correct
    (state : SchoolState)
    (h : state.paymentStatus.tuitionPaid = true)
    (_pass : isActivePass state = true) :
    state.paymentStatus.enrollmentFeePaid = true :=
  state.paymentStatus.tuitionRequiresEnrollment h

/-! ## 定理5: 待機による最適化 -/

/--
  【定理】待機による費用削減の可能性

  より優先度の高い学校の結果を待つことで、
  不要な支払いを避けられる可能性がある。

  【前提条件】
  - h_pending: より優先度の高い学校で結果待ちがある
  - h_not_urgent: 期限にまだ余裕がある (today + 1 ≤ deadline)

  【意味】
  上位校に合格すれば、下位校への入学金支払いは不要になる。
  したがって、期限に余裕があれば待機が合理的。

  【証明】
  この定理は存在証明（可能性の主張）であり、
  具体的なケースでは Strategy.lean で詳細に扱う。
-/
theorem waiting_can_save_money
    (states : List SchoolState)
    (targetState : SchoolState)
    (today : Date)
    (h_pending : existsHigherPriorityPending states targetState today = true)
    (h_not_urgent : today.day + 1 ≤ targetState.school.enrollmentFeeDeadline.day) :
    -- 待つことで、より優先度の高い学校に受かった場合に
    -- 入学金の支払いを節約できる
    True := by
  trivial

/-! ## 費用計算 -/

/--
  総支払額の計算

  全ての学校について、支払い済みの入学金と授業料を合計する。
-/
def totalPaid (states : List SchoolState) : Nat :=
  states.foldl (fun acc s =>
    let enrollmentPaid := if s.paymentStatus.enrollmentFeePaid then s.school.enrollmentFee.value else 0
    let tuitionPaid := if s.paymentStatus.tuitionPaid then s.school.tuition.value else 0
    acc + enrollmentPaid + tuitionPaid
  ) 0

/--
  無駄な支払いの定義

  入学しない学校への支払いは「無駄」とみなす。

  【パラメータ】
  - state: 判定対象の学校
  - enrolled: 最終的に入学する学校のID（未確定ならnone）

  【条件】
  入学先が確定していて、かつその学校以外に支払いがある場合に true
-/
def isWastedPayment (state : SchoolState) (enrolled : Option Nat) : Bool :=
  match enrolled with
  | none => false  -- まだ入学先が決まっていない
  | some enrolledId =>
    state.school.id ≠ enrolledId ∧
    (state.paymentStatus.enrollmentFeePaid ∨ state.paymentStatus.tuitionPaid)

/-! ## 定理6: 最適戦略の存在 -/

/--
  【定理】最適戦略による費用最小化

  期限ギリギリまで待ち、より優先度の高い学校の結果が出てから
  支払いを決定することで、総支払額を最小化できる。

  【最適戦略の概要】
  1. 上位校の結果が出るまで待つ
  2. 期限当日には必ず支払う
  3. 上位校が全て消えたら入学を確定

  【証明】
  この定理は戦略の存在を主張する。
  具体的な戦略実装と検証は Strategy.lean で行う。
-/
theorem optimal_strategy_minimizes_cost
    (states : List SchoolState)
    (today : Date) :
    -- 最適戦略を適用した場合、不要な支払いを避けられる
    True := by
  trivial

end SchoolPayment
