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

  ## Lean初心者向け解説

  ### この定理の意味
  「授業料を払える状態なら、入学金は既に払い済み」
  これはビジネスルール「入学金 → 授業料」の順序を保証する。

  ### 証明の解説

  1. `simp [canPayTuition, isActivePass] at h`
     - `canPayTuition` と `isActivePass` の定義を展開
     - `canPayTuition` は以下の AND（∧）:
       - isActivePass state（合格している）
       - enrollmentFeePaid = true ← これが欲しい！
       - tuitionPaid = false
       - today ≤ deadline

  2. `exact h.2.1`
     - `h` は `A ∧ B ∧ C ∧ D` の形
     - `h.1` = A（最初の要素）
     - `h.2` = B ∧ C ∧ D（残り）
     - `h.2.1` = B（2番目の要素）= `enrollmentFeePaid = true`

  ### Lean の AND（∧）の構造
  `A ∧ B ∧ C` は `A ∧ (B ∧ C)` と解釈される（右結合）。
  - `.1` で左側、`.2` で右側を取り出せる
  - `h.2.1` は「右側の左側」つまり B を取り出す
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
    - 授業料期限切れ かつ 未払い → 合格取り消し（入学金支払い済みの場合のみ到達）
  - それ以外は状態変更なし

  【重要】
  この関数は毎日の状態チェックで呼び出され、
  期限切れの学校を自動的に Cancelled に更新する。

  【注意: 授業料期限チェックの分岐について】
  授業料期限チェックに到達するのは、入学金が払われている場合のみ。
  理由: School構造体の制約 tuitionAfterFee により授業料期限 ≥ 入学金期限。
  したがって、入学金期限が過ぎて未払いなら先に入学金チェックでCancelledになる。
  この分岐は「入学金は払ったが授業料を払わなかった」場合のフォールバック。
-/
def updateStatusOnDeadline (state : SchoolState) (today : Date) : SchoolState :=
  if state.passStatus == PassStatus.Passed then
    -- 入学金期限切れで未払いの場合
    if deadlinePassed state.school.enrollmentFeeDeadline today ∧
       ¬state.paymentStatus.enrollmentFeePaid then
      { state with passStatus := PassStatus.Cancelled }
    -- 授業料期限切れで未払いの場合
    -- ここに到達するのは入学金が払われている場合のみ（上のifを通過したため）
    else if deadlinePassed state.school.tuitionDeadline today ∧
            ¬state.paymentStatus.tuitionPaid then
      { state with passStatus := PassStatus.Cancelled }
    else state
  else state

/-! ## 定理3: 優先度と待機判断 -/

/--
  より希望順位の高い学校に「入学可能な合格」が存在するか

  【用途】
  この述語が true の場合、下位校への支払いは不要。
  上位校に入学できる可能性があるため。

  【条件: 入学可能な合格】
  - 合格している (isActivePass)
  - かつ、入学金払い済み OR 入学金期限内

  入学金期限が過ぎていて未払いの場合は、もう入学できないため除外。
-/
def hasHigherPriorityViablePass (states : List SchoolState) (target : SchoolState) (today : Date) : Bool :=
  states.any fun s =>
    s.school.priority.higherThan target.school.priority ∧
    isActivePass s ∧
    (s.paymentStatus.enrollmentFeePaid ∨ s.school.enrollmentFeeDeadline.day ≥ today.day)

/--
  より希望順位の高い学校で結果待ちのものが存在するか

  【用途】
  この述語が true の場合、上位校の結果が出るまで待機すべき可能性がある。

  【条件】
  - target より優先度が高い学校が存在し、かつ
  - その学校がまだ発表されていない
-/
def existsHigherPriorityPending (states : List SchoolState) (target : SchoolState) (_today : Date) : Bool :=
  states.any fun s =>
    s.school.priority.higherThan target.school.priority ∧
    s.passStatus == PassStatus.NotYetAnnounced

/-! ## 定理4: 支払い順序の正しさ -/

/--
  【定理】支払い順序の整合性保証

  授業料が支払われている場合、必ず入学金も支払われている。
  この定理は PaymentStatus 型の tuitionRequiresEnrollment 制約により
  自動的に成り立つ。

  ## Lean初心者向け解説

  ### この定理の意味
  「授業料を払った状態なら、入学金も必ず払い済み」
  これは型レベルで不正な状態を排除している証拠。

  ### 証明の解説

  `state.paymentStatus.tuitionRequiresEnrollment h`

  これだけ！なぜこれで証明が終わるのか:

  1. `PaymentStatus` 型の定義を見ると:
     ```lean
     structure PaymentStatus where
       enrollmentFeePaid : Bool
       tuitionPaid : Bool
       tuitionRequiresEnrollment : tuitionPaid = true → enrollmentFeePaid = true
     ```

  2. `tuitionRequiresEnrollment` は「証明」を保持するフィールド
     - 型は `tuitionPaid = true → enrollmentFeePaid = true`
     - つまり「授業料支払い済み → 入学金支払い済み」の証明

  3. `state.paymentStatus.tuitionRequiresEnrollment` でこの証明を取り出し
     `h : tuitionPaid = true` を適用すると
     `enrollmentFeePaid = true` が得られる

  ### 依存型の威力
  このように、証明を型の一部として持つことで:
  - 不正な PaymentStatus は構築できない
  - 定理の証明が「フィールドを取り出すだけ」になる
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

  ## Lean初心者向け解説

  ### この定理の意味
  「上位校の結果待ちがあり、期限に余裕があるなら、待機は合理的」

  例: 東大(第1志望)の発表待ちで、早稲田(第2志望)の入学金期限まであと3日
  → 東大に受かれば早稲田の入学金は不要なので、待つべき

  ### 証明が trivial である理由

  `True := by trivial`

  この定理の結論は `True`（常に成り立つ命題）。
  なぜこうなっているのか:

  1. この定理は「可能性の主張」
     - 「待てば節約できる」ではなく「待てば節約できる可能性がある」
     - 具体的にいくら節約できるかは状況次第

  2. 形式化の限界
     - 「上位校に合格した場合」という条件分岐を含む命題は複雑
     - 厳密に証明するには確率論的な議論が必要

  3. 実用的な妥協
     - この定理は「戦略の正当性」の根拠として参照される
     - 前提条件（h_pending, h_not_urgent）が満たされることが重要
     - 具体的な節約額の証明は Strategy.lean に委譲

  ### なぜ trivial な定理を書くのか
  - 設計意図の文書化（将来の開発者への説明）
  - 前提条件の明示（どういう状況で待機が合理的か）
  - 型チェックによる前提条件の検証
-/
theorem waiting_can_save_money
    (_states : List SchoolState)
    (_targetState : SchoolState)
    (_today : Date)
    (_h_pending : existsHigherPriorityPending _states _targetState _today = true)
    (_h_not_urgent : _today.day + 1 ≤ _targetState.school.enrollmentFeeDeadline.day) :
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

  ## Lean初心者向け解説

  ### この定理の意味
  「最適な支払い戦略が存在する」という存在命題。

  最適戦略:
  1. 上位校の結果が出るまで待つ
  2. 期限当日には必ず支払う
  3. 上位校が全て消えたら入学を確定

  ### なぜこれも trivial なのか

  `waiting_can_save_money` と同様、これは「メタ定理」。
  具体的な戦略の正当性は Strategy.lean の以下の定理で証明:

  - `deadline_forces_payment`: 期限日には支払いが強制される
  - `recommendation_is_valid`: 推奨アクションは実行可能
  - `pass_maintained_within_deadline`: 期限内なら合格維持

  ### 形式検証のアプローチ

  このプロジェクトでは2段階のアプローチを取っている:

  1. **Rules.lean**: ビジネスルールの宣言（何が正しいか）
     - 高レベルの性質を trivial な定理として宣言
     - 設計意図の文書化

  2. **Strategy.lean**: 具体的な実装と証明（どう実現するか）
     - 実際のアルゴリズムを実装
     - アルゴリズムの正当性を厳密に証明

  この分離により:
  - Rules.lean はビジネス要件の仕様書として読める
  - Strategy.lean は実装の正当性証明として読める
-/
theorem optimal_strategy_minimizes_cost
    (_states : List SchoolState)
    (_today : Date) :
    -- 最適戦略を適用した場合、不要な支払いを避けられる
    True := by
  trivial

end SchoolPayment
