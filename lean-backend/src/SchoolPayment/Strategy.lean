/-
  SchoolPayment/Strategy.lean

  最適支払い戦略のアルゴリズムと正当性の証明

  【このファイルの目的】
  Rules.lean で定義したビジネスルールを基に、
  具体的な支払い判定アルゴリズムを実装し、
  その正当性を定理として証明する。

  【戦略の核心】
  1. 最上位校に合格したら、すぐに入学金を払う
  2. 入学金は、より優先度の高い学校の結果が全て出るか、期限が来るまで待つ
  3. 授業料は、その学校に入学することが確定するか、期限が来るまで待つ
  4. 期限当日は必ず支払う（それ以外に選択肢がない）

  【主要な定理】
  - deadline_forces_payment: 期限日には支払いが強制される
  - enrollment_before_tuition: 入学金は授業料より先
  - recommendation_is_valid: 推奨アクションは常に実行可能
  - pass_maintained_within_deadline: 期限内なら合格は維持される
-/

import SchoolPayment.Types
import SchoolPayment.Rules
import Batteries.Tactic.Init

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
  1. 合格している、入学金未払い、期限内
  2. より優先度の高い学校に「入学可能な合格」がない
     ※入学可能 = 合格 AND (入学金払い済み OR 入学金期限内)
  3. 以下のいずれか:
     a. 上位校がない（第1志望に合格）
     b. 今日が期限日（これ以上待てない）
     c. 上位校が全て消滅（不合格/取消/入学確定/入学金期限切れ）
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

      -- 上位校がない場合（第1志望）は、すぐに払う
      if higherPrioritySchools.isEmpty then true
      -- 期限日なら必ず払う
      else if isDeadlineToday then true
      else
        -- 上位校が全て「消えた」かどうか
        -- 消えた = 不合格 or 取り消し or 入学確定（授業料まで払い済み）
        --       or 合格しているが入学金期限切れ（入学金未払いで期限過ぎ）
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

  入学可能 = 合格 AND (入学金払い済み OR 入学金期限内)

  ## Lean初心者向け解説

  ### この定理が証明すること
  「今日が入学金の支払期限で、上位校に入学可能な合格がない場合、
  shouldPayEnrollmentFee は必ず true を返す」

  ### 仮定（前提条件）の意味
  - `h_can_pay`: この学校に入学金を払える状態（合格・未払い・期限内）
  - `h_deadline`: 今日が支払期限当日
  - `h_no_higher_viable`: 上位校に「入学可能な合格」が1つもない

  ### 証明の流れ

  1. `simp only [shouldPayEnrollmentFee, h_can_pay]`
     - `shouldPayEnrollmentFee` の定義を展開
     - `h_can_pay = true` なので最初の if を通過

  2. `have h_not_any : ... = false`
     - `any` が false であることを示す補助命題を立てる
     - これは `h_no_higher_viable`（all が true）の対偶

  3. `by_contra h_contra`
     - 背理法: 「any = false でない」と仮定して矛盾を導く

  4. `have h_any : _ = true := (Bool.not_eq_false _).mp h_contra`
     - 「false でない」から「true である」を導く

  5. `rw [List.any_eq_true] at h_any`
     - `any` が true ⟺ 条件を満たす要素が存在する

  6. `obtain ⟨s, hs_mem, hs_viable⟩ := h_any`
     - 存在する要素 s とその証明を取り出す

  7. `have h_not := List.all_eq_true.mp h_no_higher_viable s hs_mem`
     - `all` が true なら、s も条件を満たす

  8. `exact h_not (eq_true hs_viable)`
     - しかし h_not は「s は条件を満たさない」と言っている
     - これは hs_viable と矛盾 → 背理法完了

  9. `simp_all`
     - 残りの if 式を h_deadline と h_not_any で簡約
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
  simp only [shouldPayEnrollmentFee, h_can_pay]
  -- 上位校に入学可能な合格がないことを示す
  have h_not_any : (states.filter fun s => s.school.priority.higherThan target.school.priority).any
      (fun s => isActivePass s ∧ (s.paymentStatus.enrollmentFeePaid ∨ s.school.enrollmentFeeDeadline.day ≥ today.day)) = false := by
    by_contra h_contra
    have h_any : _ = true := (Bool.not_eq_false _).mp h_contra
    rw [List.any_eq_true] at h_any
    obtain ⟨s, hs_mem, hs_viable⟩ := h_any
    have h_not := List.all_eq_true.mp h_no_higher_viable s hs_mem
    simp only [decide_eq_true_eq] at h_not hs_viable
    exact h_not (eq_true hs_viable)
  simp_all

/--
  【定理】入学金支払いは常に授業料支払いの前提条件

  shouldPayTuition が true なら、必ず入学金は支払い済み。
  これは canPayTuition の定義から導かれる。

  ## Lean初心者向け解説

  ### この定理が証明すること
  「授業料の支払いが推奨されるなら、入学金は既に払い済み」
  これはビジネスルール「入学金を払わないと授業料は払えない」を形式化している。

  ### 証明の解説

  1. `simp only [shouldPayTuition, canPayTuition, isActivePass] at h`
     - 関数定義を展開して、h の中身を具体化
     - `canPayTuition` の定義には `enrollmentFeePaid` の条件が含まれる

  2. `split at h`
     - `shouldPayTuition` 内の if 式で場合分け
     - `¬canPayTuition` の場合は h = false で矛盾
     - `canPayTuition` の場合は `enrollmentFeePaid = true` が含まれる

  3. `simp_all`
     - 各分岐で仮定を整理し、`enrollmentFeePaid = true` を導出
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
  - 上位校なし（第一志望）: 「第一志望に合格しました」
  - それ以外: 「上位校の結果が出ました」
-/
def getRecommendationForSchool
    (states : List SchoolState)
    (state : SchoolState)
    (today : Date) : Option Recommendation :=
  -- 入学金支払いをチェック
  if shouldPayEnrollmentFee states state today then
    let urgency := daysUntilDeadline state.school.enrollmentFeeDeadline today
    let amountStr := formatAmount state.school.enrollmentFee.value
    let higherPrioritySchools := states.filter fun s =>
      s.school.priority.higherThan state.school.priority
    let reason :=
      if urgency == 0 then
        s!"{state.school.name}の入学金支払期限です（¥{amountStr}）。支払わないと合格取り消しになります。"
      else if higherPrioritySchools.isEmpty then
        s!"{state.school.name}の入学金（¥{amountStr}）を支払う必要があります。第一志望に合格しました。"
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

  ## Lean初心者向け解説

  ### この補題の意味
  「入学金を払うべき」と判定されたら、「入学金を払える状態」である。
  当たり前に見えるが、この補題があると他の定理の証明が楽になる。

  ### 証明の解説

  1. `simp only [shouldPayEnrollmentFee] at h`
     - `shouldPayEnrollmentFee` の定義を展開
     - 最初に `if ¬canPayEnrollmentFee then false` がある

  2. `split at h`
     - この if で場合分け
     - `¬canPayEnrollmentFee` なら h = false で矛盾
     - `canPayEnrollmentFee` なら目標達成

  3. `simp_all`
     - 二重否定を解消して `canPayEnrollmentFee = true` を導出
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

  ## Lean初心者向け解説

  証明の構造は `shouldPayEnrollmentFee_implies_canPay` と全く同じ。
  `shouldPayTuition` も最初に `canPayTuition` をチェックしているため。
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

  ## Lean初心者向け解説

  ### この定理の意義
  「システムが推奨する支払いは、必ず実行可能である」
  これにより「払えない支払いを推奨する」バグが型レベルで排除される。

  ### 定理の構造
  結論は `∧`（かつ）で繋がれた2つの命題:
  1. アクションが PayEnrollmentFee なら canPayEnrollmentFee = true
  2. アクションが PayTuition なら canPayTuition = true

  ### 証明の解説

  1. `simp only [getRecommendationForSchool] at h`
     - 関数定義を展開

  2. `constructor`
     - `∧` を証明するため、2つの部分に分ける

  3. `intro h_action`
     - 「→」を証明するため、左辺を仮定に追加

  4. `split at h`
     - `getRecommendationForSchool` 内の if で場合分け
     - `shouldPayEnrollmentFee = true` の分岐
     - `shouldPayTuition = true` の分岐
     - どちらも false の分岐（h = none で矛盾）

  5. `exact shouldPayEnrollmentFee_implies_canPay ...`
     - 先に証明した補題を適用

  6. `simp at h_action`
     - アクションの種類が合わない場合は矛盾を導出
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

  ## Lean初心者向け解説

  ### この定理の意義
  「期限内なら、システムが勝手に合格を取り消さない」
  これは updateStatusOnDeadline 関数の正当性を保証する。

  ### 前提条件の意味
  - `h_pass`: 現在合格している
  - `h_within_enroll`: 今日 ≤ 入学金期限
  - `h_within_tuition`: 今日 ≤ 授業料期限

  ### 結論の意味
  `(updateStatusOnDeadline state today).passStatus = Passed ∨ enrollmentFeePaid = false`
  - 更新後も Passed のまま、または
  - そもそも入学金が未払い（この場合は取り消しが正当）

  ### 証明の解説

  1. `simp only [updateStatusOnDeadline, isActivePass, deadlinePassed, beq_iff_eq] at *`
     - 関数定義を全て展開
     - `*` は全ての仮定と目標に適用

  2. `split`
     - `updateStatusOnDeadline` 内の最初の if で場合分け
     - 合格している場合としていない場合

  3. `rename_i h_deadline`
     - 無名の仮定に名前を付ける

  4. `simp only [decide_eq_true_eq] at h_deadline`
     - `decide` を展開して Bool から Prop へ変換

  5. `omega`
     - 線形算術ソルバー
     - `h_within_enroll: today.day ≤ deadline.day` と
     - `h_deadline: today.day > deadline.day` は矛盾
     - よってこの分岐は到達不能

  6. `left; exact h_passed`
     - 期限切れでない場合、状態は変わらない
     - `∨` の左側（Passed のまま）を証明
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
