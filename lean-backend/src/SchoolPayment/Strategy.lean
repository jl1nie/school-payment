/-
  SchoolPayment/Strategy.lean

  最適支払い戦略のアルゴリズムと正当性の証明

  【このファイルの目的】
  Rules.lean で定義したビジネスルールを基に、
  具体的な支払い判定アルゴリズムを実装し、
  その正当性を定理として証明する。

  【戦略の核心】
  1. 入学金は、より優先度の高い学校の結果が全て出るか、期限が来るまで待つ
  2. 授業料は、その学校に入学することが確定するか、期限が来るまで待つ
  3. 期限当日は必ず支払う（それ以外に選択肢がない）

  【主要な定理】
  - deadline_forces_payment: 期限日には支払いが強制される
  - enrollment_before_tuition: 入学金は授業料より先
  - recommendation_is_valid: 推奨アクションは常に実行可能
  - pass_maintained_within_deadline: 期限内なら合格は維持される
-/

import SchoolPayment.Types
import SchoolPayment.Rules
import Mathlib.Tactic

namespace SchoolPayment

/-! ## ユーティリティ関数 -/

/-- 金額を3桁区切りでフォーマット（例: 200000 → "200,000"） -/
def formatAmount (n : Nat) : String :=
  let chars := (toString n).toList
  let len := chars.length
  if len <= 3 then toString n
  else
    -- 逆順にして3文字ごとにカンマを入れる
    let rec insertCommas (cs : List Char) (count : Nat) : List Char :=
      match cs with
      | [] => []
      | c :: rest =>
        if count > 0 && count % 3 == 0 then
          ',' :: c :: insertCommas rest (count + 1)
        else
          c :: insertCommas rest (count + 1)
    String.ofList (insertCommas chars.reverse 0).reverse

/-! ## 支払い判定ロジック -/

/--
  入学金支払いが必要かどうかを判定

  【支払いが必要な条件】
  1. 合格している
  2. 入学金未払い
  3. 期限内
  4. より優先度の高い学校に「入学可能な合格」がない
     ※入学可能 = 合格 AND (入学金払い済み OR 入学金期限内)
  5. 以下のいずれか:
     a. 今日が期限日（これ以上待てない）
     b. 上位校が存在し、全て消滅（不合格/取消/入学確定/入学金期限切れ）

  【設計思想】
  - 上位校に入学可能な合格がある場合、下位校は払わない（期限日でも）
  - 上位校の入学可能な合格がない場合のみ、期限日または上位校消滅時に払う
  - 上位校がまだ望みがある（未発表 or 合格して入学金期限内）場合は待機
  - 最上位校（上位校なし）の場合は、期限日まで待つ（早く払う必要がない）
-/
def shouldPayEnrollmentFee
    (states : List SchoolState)
    (target : SchoolState)
    (today : Date) : Bool :=
  -- 基本条件をチェック（合格・未払い・期限内）
  if ¬canPayEnrollmentFee target today then false
  else
    -- より優先度の高い学校の状況をチェック
    let higherPrioritySchools := states.filter fun s =>
      s.school.priority.higherThan target.school.priority

    -- 上位校に「入学可能な合格」があるかどうか
    -- 合格していて、かつ（入学金払い済み OR 入学金期限内）なら入学可能
    -- この場合、下位校の入学金を払う必要はない
    let hasHigherPriorityViablePass := higherPrioritySchools.any fun s =>
      isActivePass s ∧
      (s.paymentStatus.enrollmentFeePaid ∨ s.school.enrollmentFeeDeadline.day ≥ today.day)

    -- 上位校に入学可能な合格がある場合は、この学校の入学金を払わない
    if hasHigherPriorityViablePass then false
    else
      -- 今日が期限日なら払う（上位校に入学可能な合格がないため）
      let isDeadlineToday := today.day == target.school.enrollmentFeeDeadline.day

      -- 期限日なら必ず払う
      if isDeadlineToday then true
      else
        -- 上位校が全て「消えた」かどうか（かつ上位校が存在する場合のみ）
        -- 消えた = 不合格 or 取り消し or 入学確定（授業料まで払い済み）
        --       or 合格しているが入学金期限切れ（入学金未払いで期限過ぎ）
        -- 上位校がない場合は、期限日まで待つ
        if higherPrioritySchools.isEmpty then false
        else
          higherPrioritySchools.all fun s =>
            s.passStatus == PassStatus.Failed ∨
            s.passStatus == PassStatus.Cancelled ∨
            -- 合格していて入学金・授業料まで払い済み（入学確定）
            (isActivePass s ∧ s.paymentStatus.tuitionPaid) ∨
            -- 合格しているが入学金期限切れで未払い（もう入学できない）
            (isActivePass s ∧ ¬s.paymentStatus.enrollmentFeePaid ∧ s.school.enrollmentFeeDeadline.day < today.day)

/--
  授業料支払いが必要かどうかを判定

  【支払いが必要な条件】
  1. 合格している
  2. 入学金支払い済み
  3. 授業料未払い
  4. 期限内
  5. 以下のいずれか:
     a. 今日が期限日
     b. この学校に入学することが確定（より優先度の高い学校が全て消えた）

  【設計思想】
  授業料を払う = 入学確定 なので、より慎重に判断する。
  上位校が全て消えた場合のみ、期限前でも払って良い。
-/
def shouldPayTuition
    (states : List SchoolState)
    (target : SchoolState)
    (today : Date) : Bool :=
  -- 基本条件をチェック
  if ¬canPayTuition target today then false
  else
    -- 今日が期限日なら必ず払う
    let isDeadlineToday := today.day == target.school.tuitionDeadline.day
    -- より優先度の高い学校が全て消えているか
    let higherPrioritySchools := states.filter fun s =>
      s.school.priority.higherThan target.school.priority
    let allHigherPriorityGone := higherPrioritySchools.all fun s =>
      s.passStatus == PassStatus.Failed ∨ s.passStatus == PassStatus.Cancelled

    isDeadlineToday ∨ allHigherPriorityGone

/-! ## 定理: 支払い判定の正当性 -/

/--
  【定理】期限日で上位校に入学可能な合格がなければ支払いが推奨される

  期限当日で支払い可能な状態で、かつ上位校に入学可能な合格がない場合、
  shouldPayEnrollmentFee は必ず true を返す。
  これにより、期限切れによる合格取り消しを防ぐ。

  【注意】
  上位校に入学可能な合格がある場合は、期限日でも下位校の入学金は払わない。
  上位校の入学金を先に払うべきだから。

  入学可能 = 合格 AND (入学金払い済み OR 入学金期限内)

  【証明戦略】
  1. shouldPayEnrollmentFee を展開
  2. h_can_pay により基本条件が満たされていることを利用
  3. h_no_higher_viable により上位校に入学可能な合格がないことを利用
  4. h_deadline により isDeadlineToday = true
  5. ∨ の左側が true なので全体が true
-/
theorem deadline_forces_payment
    (states : List SchoolState)
    (target : SchoolState)
    (today : Date)
    (h_can_pay : canPayEnrollmentFee target today = true)
    (h_deadline : today.day = target.school.enrollmentFeeDeadline.day)
    (h_no_higher_viable : (states.filter fun s => s.school.priority.higherThan target.school.priority).all
      fun s => ¬(isActivePass s ∧ (s.paymentStatus.enrollmentFeePaid ∨ s.school.enrollmentFeeDeadline.day ≥ today.day)) = true) :
    shouldPayEnrollmentFee states target today = true := by
  simp only [shouldPayEnrollmentFee]
  simp only [h_can_pay]
  -- 上位校に入学可能な合格がないことを示す
  have h_not_any : (List.filter (fun s => s.school.priority.higherThan target.school.priority) states).any
    (fun s => isActivePass s ∧ (s.paymentStatus.enrollmentFeePaid ∨ s.school.enrollmentFeeDeadline.day ≥ today.day)) = false := by
    by_contra h_contra
    push_neg at h_contra
    have h_any_true : (List.filter (fun s => s.school.priority.higherThan target.school.priority) states).any
      (fun s => isActivePass s ∧ (s.paymentStatus.enrollmentFeePaid ∨ s.school.enrollmentFeeDeadline.day ≥ today.day)) = true := Bool.eq_true_of_not_eq_false h_contra
    rw [List.any_eq_true] at h_any_true
    obtain ⟨s, hs_mem, hs_viable⟩ := h_any_true
    have h_all := List.all_eq_true.mp h_no_higher_viable s hs_mem
    simp only [decide_eq_true_eq] at h_all
    simp only [decide_eq_true_eq] at hs_viable
    have hs_eq_true : (isActivePass s = true ∧ (s.paymentStatus.enrollmentFeePaid = true ∨ s.school.enrollmentFeeDeadline.day ≥ today.day)) = True := eq_true hs_viable
    exact h_all hs_eq_true
  simp only [h_not_any]
  -- h_deadline により isDeadlineToday = true
  simp only [h_deadline, beq_self_eq_true]
  -- if false = true then false else if true = true then true else ...
  simp only [Bool.false_eq_true, ↓reduceIte]
  -- (if ¬True then false else true) = true
  simp only [not_true_eq_false, ↓reduceIte]

/--
  【定理】入学金支払いは常に授業料支払いの前提条件

  shouldPayTuition が true なら、必ず入学金は支払い済み。
  これは canPayTuition の定義から導かれる。

  【証明戦略】
  shouldPayTuition の定義を展開し、canPayTuition の条件から
  enrollmentFeePaid = true を抽出する。
-/
theorem enrollment_before_tuition
    (_states : List SchoolState)
    (target : SchoolState)
    (today : Date)
    (h : shouldPayTuition _states target today = true) :
    target.paymentStatus.enrollmentFeePaid = true := by
  simp only [shouldPayTuition, canPayTuition, isActivePass] at h
  split at h <;> simp_all

/-! ## 推奨アクション生成 -/

/--
  期限までの日数を計算

  urgency（緊急度）の計算に使用。
  0 = 本日期限（最も緊急）
-/
def daysUntilDeadline (deadline : Date) (today : Date) : Nat :=
  if deadline.day ≥ today.day then deadline.day - today.day else 0

/--
  単一の学校に対する推奨アクションを生成

  【優先順位】
  1. 入学金支払いが必要なら入学金を推奨
  2. 入学金が済んでいて授業料支払いが必要なら授業料を推奨
  3. どちらも必要なければ None

  【理由メッセージの生成】
  - urgency = 0（期限当日）: 「本日が期限です」
  - urgency > 0: 「上位校の結果が出ました」
-/
def getRecommendationForSchool
    (states : List SchoolState)
    (state : SchoolState)
    (today : Date) : Option Recommendation :=
  -- 入学金支払いをチェック
  if shouldPayEnrollmentFee states state today then
    let urgency := daysUntilDeadline state.school.enrollmentFeeDeadline today
    let amountStr := formatAmount state.school.enrollmentFee.value
    let reason :=
      if urgency == 0 then
        s!"{state.school.name}の入学金支払期限です（¥{amountStr}）。支払わないと合格取り消しになります。"
      else
        s!"{state.school.name}の入学金（¥{amountStr}）を支払う必要があります。上位校の結果が全て出ました。"
    some ⟨PaymentAction.PayEnrollmentFee state.school.id, reason, urgency⟩
  -- 授業料支払いをチェック
  else if shouldPayTuition states state today then
    let urgency := daysUntilDeadline state.school.tuitionDeadline today
    let amountStr := formatAmount state.school.tuition.value
    let reason :=
      if urgency == 0 then
        s!"{state.school.name}の授業料支払期限です（¥{amountStr}）。支払わないと合格取り消しになります。"
      else
        s!"{state.school.name}の授業料（¥{amountStr}）を支払う必要があります。入学が確定しています。"
    some ⟨PaymentAction.PayTuition state.school.id, reason, urgency⟩
  else
    none

/--
  全ての学校を評価し、推奨アクションのリストを生成

  【処理】
  1. 各学校に対して getRecommendationForSchool を呼び出し
  2. Some の結果のみを収集
  3. 緊急度順（urgency昇順）でソート

  urgency が小さいほど緊急度が高いため、昇順ソート。
-/
def getAllRecommendations
    (states : List SchoolState)
    (today : Date) : List Recommendation :=
  let recs := states.filterMap fun state =>
    getRecommendationForSchool states state today
  -- 緊急度でソート（urgencyが小さい＝緊急度が高い）
  recs.toArray.qsort (fun r1 r2 => r1.urgency < r2.urgency) |>.toList

/--
  最も優先度の高い推奨アクションを取得

  【処理】
  getAllRecommendations の先頭を返す。
  空の場合は DoNothing を返す。
-/
def getTopRecommendation
    (states : List SchoolState)
    (today : Date) : Recommendation :=
  match getAllRecommendations states today with
  | [] => ⟨PaymentAction.DoNothing, "現時点で支払いが必要な学校はありません。", 999⟩
  | r :: _ => r

/-! ## 正当性の証明 -/

/--
  【補題】shouldPayEnrollmentFee が true なら canPayEnrollmentFee も true

  支払いが推奨されるなら、それは実行可能な支払いである。

  【証明戦略】
  shouldPayEnrollmentFee の定義で、最初に canPayEnrollmentFee をチェックしている。
  false なら早期リターンするため、true が返るなら canPayEnrollmentFee は true。
-/
theorem shouldPayEnrollmentFee_implies_canPay
    (states : List SchoolState)
    (state : SchoolState)
    (today : Date)
    (h : shouldPayEnrollmentFee states state today = true) :
    canPayEnrollmentFee state today = true := by
  simp only [shouldPayEnrollmentFee] at h
  split at h <;> simp_all

/--
  【補題】shouldPayTuition が true なら canPayTuition も true

  shouldPayEnrollmentFee_implies_canPay と同様の補題。
-/
theorem shouldPayTuition_implies_canPay
    (states : List SchoolState)
    (state : SchoolState)
    (today : Date)
    (h : shouldPayTuition states state today = true) :
    canPayTuition state today = true := by
  simp only [shouldPayTuition] at h
  split at h <;> simp_all

/--
  【定理】推奨される支払いは全て有効な支払いである

  getRecommendationForSchool が Some を返す場合、
  そのアクションは canPay* で検証済みである。

  【証明戦略】
  getRecommendationForSchool の各分岐を検査し、
  - PayEnrollmentFee の場合: shouldPayEnrollmentFee_implies_canPay を使用
  - PayTuition の場合: shouldPayTuition_implies_canPay を使用

  【意義】
  この定理により、システムが推奨する支払いは
  必ず実行可能であることが保証される。
  「支払えない支払いを推奨する」バグを型レベルで排除。
-/
theorem recommendation_is_valid
    (states : List SchoolState)
    (state : SchoolState)
    (today : Date)
    (rec : Recommendation)
    (h : getRecommendationForSchool states state today = some rec) :
    (rec.action = PaymentAction.PayEnrollmentFee state.school.id →
      canPayEnrollmentFee state today = true) ∧
    (rec.action = PaymentAction.PayTuition state.school.id →
      canPayTuition state today = true) := by
  simp only [getRecommendationForSchool] at h
  constructor
  · intro h_action
    split at h
    · exact shouldPayEnrollmentFee_implies_canPay states state today (by assumption)
    · split at h
      · -- shouldPayTuition = true だが action は PayEnrollmentFee
        simp only [Option.some.injEq] at h
        rw [← h] at h_action
        simp at h_action
      · simp at h
  · intro h_action
    split at h
    · -- shouldPayEnrollmentFee = true だが action は PayTuition
      simp only [Option.some.injEq] at h
      rw [← h] at h_action
      simp at h_action
    · split at h
      · exact shouldPayTuition_implies_canPay states state today (by assumption)
      · simp at h

/--
  【定理】期限内であれば合格は維持される

  入学金期限内かつ授業料期限内であれば、
  updateStatusOnDeadline を適用しても合格状態は維持される。
  （ただし入学金未払いの場合は除く）

  【前提条件】
  - h_pass: 現在合格している
  - h_within_enroll: 今日 ≤ 入学金期限
  - h_within_tuition: 今日 ≤ 授業料期限

  【結論】
  更新後も Passed のまま、または入学金が未払い

  【証明戦略】
  updateStatusOnDeadline の各分岐を検査。
  期限切れ条件は today.day > deadline.day だが、
  h_within_* により today.day ≤ deadline.day なので
  期限切れ条件は成り立たない（omega で自動証明）。
-/
theorem pass_maintained_within_deadline
    (state : SchoolState)
    (today : Date)
    (h_pass : isActivePass state = true)
    (h_within_enroll : today.day ≤ state.school.enrollmentFeeDeadline.day)
    (h_within_tuition : today.day ≤ state.school.tuitionDeadline.day) :
    (updateStatusOnDeadline state today).passStatus = PassStatus.Passed ∨
    state.paymentStatus.enrollmentFeePaid = false := by
  simp only [updateStatusOnDeadline, isActivePass, deadlinePassed, beq_iff_eq] at *
  split
  · rename_i h_passed
    split
    · -- 入学金期限切れで未払い → 取り消し
      -- しかし h_within_enroll より今日 ≤ 入学金期限 なので、期限切れではない
      rename_i h_deadline
      simp only [decide_eq_true_eq] at h_deadline
      omega
    · rename_i h_not_enroll_deadline
      split
      · -- 授業料期限切れで未払い → 取り消し
        -- しかし h_within_tuition より今日 ≤ 授業料期限 なので、期限切れではない
        rename_i h_tuition_deadline
        simp only [decide_eq_true_eq] at h_tuition_deadline
        omega
      · left; exact h_passed
  · simp_all

end SchoolPayment
