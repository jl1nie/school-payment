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

/-! ## 推奨アクションの適用 -/

/--
  推奨アクションを状態に反映する

  【処理】
  - PayEnrollmentFee → 対象学校の入学金を支払い済みに
  - PayTuition → 対象学校の授業料を支払い済みに（入学金も true に）
  - DoNothing → 変更なし

  【用途】
  週間推奨計算で、推奨アクションを実行した後の状態をシミュレートする際に使用。
-/
def applyRecommendedAction (states : List SchoolState) (action : PaymentAction) : List SchoolState :=
  match action with
  | .PayEnrollmentFee schoolId =>
    states.map fun s =>
      if s.school.id == schoolId then
        { s with paymentStatus := mkPaymentStatus true s.paymentStatus.tuitionPaid }
      else s
  | .PayTuition schoolId =>
    states.map fun s =>
      if s.school.id == schoolId then
        { s with paymentStatus := mkPaymentStatus true true }
      else s
  | .DoNothing => states

/--
  【定理】applyRecommendedAction は入学金支払いを正しく反映する

  PayEnrollmentFee アクションを適用した後、対象学校の enrollmentFeePaid は true になる。

  ## Lean初心者向け解説

  ### この定理の意義
  「入学金支払い推奨を適用したら、確実にその学校の入学金が支払い済みになる」
  これにより、週間推奨の累積計算が正しく動作することが保証される。

  ### 証明の解説
  1. `simp only [applyRecommendedAction, List.mem_map]`
     - 関数定義と List.map の性質を展開
  2. `obtain ⟨original, h_orig_mem, h_eq⟩ := h_mem`
     - s が元リストのある要素から変換されたことを取り出す
  3. 場合分けで、対象学校なら true、そうでなければ仮定を使う
-/
theorem applyRecommendedAction_enrollmentFee_correct
    (states : List SchoolState)
    (schoolId : Nat)
    (s : SchoolState)
    (h_mem : s ∈ applyRecommendedAction states (.PayEnrollmentFee schoolId))
    (h_id : s.school.id = schoolId) :
    s.paymentStatus.enrollmentFeePaid = true := by
  simp only [applyRecommendedAction, List.mem_map] at h_mem
  obtain ⟨original, h_orig_mem, h_eq⟩ := h_mem
  simp only [beq_iff_eq] at h_eq
  split at h_eq
  · -- original.school.id = schoolId の場合
    rw [← h_eq]
    simp [mkPaymentStatus]
  · -- original.school.id ≠ schoolId の場合
    rw [← h_eq] at h_id
    rename_i h_ne
    exact absurd h_id h_ne

/--
  【定理】applyRecommendedAction は授業料支払いを正しく反映する

  PayTuition アクションを適用した後、対象学校の tuitionPaid は true になる。
-/
theorem applyRecommendedAction_tuition_correct
    (states : List SchoolState)
    (schoolId : Nat)
    (s : SchoolState)
    (h_mem : s ∈ applyRecommendedAction states (.PayTuition schoolId))
    (h_id : s.school.id = schoolId) :
    s.paymentStatus.tuitionPaid = true := by
  simp only [applyRecommendedAction, List.mem_map] at h_mem
  obtain ⟨original, h_orig_mem, h_eq⟩ := h_mem
  simp only [beq_iff_eq] at h_eq
  split at h_eq
  · rw [← h_eq]
    simp [mkPaymentStatus]
  · rw [← h_eq] at h_id
    rename_i h_ne
    exact absurd h_id h_ne

/--
  【定理】DoNothing は状態を変更しない
-/
theorem applyRecommendedAction_doNothing
    (states : List SchoolState) :
    applyRecommendedAction states .DoNothing = states := by
  simp [applyRecommendedAction]

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

/-! ## 入学可能な合格校に対する推奨保証 -/

/--
  入学可能な合格校の定義

  合格していて、かつ（入学金払い済み OR 入学金期限内）なら入学可能。
  この状態の学校は、まだ入学の選択肢として有効である。
-/
def isViablePass (state : SchoolState) (today : Date) : Bool :=
  isActivePass state ∧
  (state.paymentStatus.enrollmentFeePaid ∨ state.school.enrollmentFeeDeadline.day ≥ today.day)

/--
  【定理】最優先の未払い入学可能校は、上位に入学可能校がなければ期限日に推奨される

  ## 定理の意義
  この定理は「合格を見逃さない」という核心的な保証を与える。
  ある学校が：
  - 入学可能（合格かつ入学金期限内）
  - 入学金未払い
  - より優先度の高い入学可能校が存在しない
  という条件を満たすとき、その入学金期限日には必ず支払いが推奨される。
-/
theorem highest_unpaid_viable_on_deadline_recommended
    (states : List SchoolState)
    (today : Date)
    (target : SchoolState)
    (h_viable : isViablePass target today = true)
    (h_not_paid : target.paymentStatus.enrollmentFeePaid = false)
    (h_deadline : today.day = target.school.enrollmentFeeDeadline.day)
    (h_no_higher_viable : (states.filter fun s =>
        s.school.priority.higherThan target.school.priority).all
        (fun s => ¬isViablePass s today) = true) :
    shouldPayEnrollmentFee states target today = true := by
  have h_can_pay : canPayEnrollmentFee target today = true := by
    simp only [canPayEnrollmentFee, isActivePass, LE.le]
    simp only [isViablePass, isActivePass] at h_viable
    simp only [decide_eq_true_eq] at h_viable ⊢
    obtain ⟨h_pass, h_or⟩ := h_viable
    refine ⟨h_pass, ?_, ?_⟩
    · simp only [h_not_paid]; decide
    · cases h_or with
      | inl h => simp [h_not_paid] at h
      | inr h => omega

  have h_no_higher_viable' : (states.filter fun s =>
      s.school.priority.higherThan target.school.priority).all
      (fun s => ¬(isActivePass s ∧
        (s.paymentStatus.enrollmentFeePaid ∨ s.school.enrollmentFeeDeadline.day ≥ today.day)) = true) = true := by
    rw [List.all_eq_true] at h_no_higher_viable ⊢
    intro s hs
    have h_not_viable := h_no_higher_viable s hs
    -- h_not_viable : (decide ¬isViablePass s today = true) = true
    simp only [decide_eq_true_eq] at h_not_viable
    -- h_not_viable : ¬(isViablePass s today = true)
    simp only [isViablePass, isActivePass] at h_not_viable
    -- 目標 : ¬(...) = true
    simp only [decide_eq_true_eq, eq_iff_iff, iff_true]
    intro ⟨h_pass, h_or⟩
    apply h_not_viable
    simp only [decide_eq_true_eq]
    exact ⟨h_pass, h_or⟩

  exact deadline_forces_payment states target today h_can_pay h_deadline h_no_higher_viable'

/--
  【定理】入学可能な合格校が存在し、その最優先校が未払いで、
  上位に入学可能校がなければ、期限日に支払いが推奨される

  ## 定理の意義
  この定理は top_viable_unpaid_implies_recommendation の前段階。
  all 述語ではなく forall 述語を使った形式。
-/
theorem top_viable_unpaid_implies_recommendation
    (states : List SchoolState)
    (target : SchoolState)
    (_h_in_states : target ∈ states)
    (h_pass : isActivePass target = true)
    (h_not_paid : target.paymentStatus.enrollmentFeePaid = false)
    (h_no_higher_viable : ∀ s ∈ states,
        s.school.priority.higherThan target.school.priority →
        ¬isViablePass s (Date.mk target.school.enrollmentFeeDeadline.day)) :
    shouldPayEnrollmentFee states target (Date.mk target.school.enrollmentFeeDeadline.day) = true := by
  let today := Date.mk target.school.enrollmentFeeDeadline.day

  have h_target_viable : isViablePass target today = true := by
    simp only [isViablePass, isActivePass, decide_eq_true_eq]
    exact ⟨h_pass, Or.inr (Nat.le_refl _)⟩

  have h_no_higher_all : (states.filter fun s =>
      s.school.priority.higherThan target.school.priority).all
      (fun s => ¬isViablePass s today) = true := by
    rw [List.all_eq_true]
    intro s hs
    simp only [List.mem_filter] at hs
    obtain ⟨hs_in_states, hs_higher⟩ := hs
    have h_not := h_no_higher_viable s hs_in_states hs_higher
    -- h_not : ¬isViablePass s today = true
    -- 目標 : (decide ¬isViablePass s today = true) = true
    simp only [decide_eq_true_eq]
    exact h_not

  exact highest_unpaid_viable_on_deadline_recommended states today target
    h_target_viable h_not_paid rfl h_no_higher_all

/--
  【定理】入学可能校が存在し、最優先の入学可能校が未払いなら、期限日に推奨される

  ## 定理の意義
  「合格を見逃さない」という核心的保証の最も単純な形。

  入学可能な合格校の中で最も優先度の高いもの（best）が未払いであれば、
  best の入学金期限日に必ず支払いが推奨される。

  ## 重要な帰結
  未払いの入学可能校がある限り、その中の最優先校の期限日には必ず推奨が出る。
  したがって、ユーザーが毎日システムを確認すれば、支払い期限を逃すことはない。
-/
theorem highest_viable_unpaid_recommended_on_deadline
    (states : List SchoolState)
    (best : SchoolState)
    (h_in_states : best ∈ states)
    (h_pass : isActivePass best = true)
    (h_not_paid : best.paymentStatus.enrollmentFeePaid = false)
    (h_highest_viable : ∀ s ∈ states,
        isViablePass s (Date.mk best.school.enrollmentFeeDeadline.day) = true →
        best.school.priority.rank ≤ s.school.priority.rank) :
    shouldPayEnrollmentFee states best (Date.mk best.school.enrollmentFeeDeadline.day) = true := by
  let today := Date.mk best.school.enrollmentFeeDeadline.day

  -- best は入学可能
  have h_best_viable : isViablePass best today = true := by
    simp only [isViablePass, isActivePass, decide_eq_true_eq]
    exact ⟨h_pass, Or.inr (Nat.le_refl _)⟩

  -- best より上位に入学可能校がない
  have h_no_higher : ∀ s ∈ states,
      s.school.priority.higherThan best.school.priority →
      ¬isViablePass s today := by
    intro s hs_in hs_higher
    intro h_s_viable
    have h_le := h_highest_viable s hs_in h_s_viable
    simp only [Priority.higherThan, decide_eq_true_eq] at hs_higher
    -- hs_higher : s.school.priority.rank < best.school.priority.rank
    -- h_le : best.school.priority.rank ≤ s.school.priority.rank
    -- これは矛盾
    have : s.school.priority.rank < s.school.priority.rank := Nat.lt_of_lt_of_le hs_higher h_le
    exact Nat.lt_irrefl _ this

  exact top_viable_unpaid_implies_recommendation states best
    h_in_states h_pass h_not_paid h_no_higher

/-! ## 授業料支払いの網羅性 -/

/--
  授業料支払い可能な状態の定義

  入学金払い済みで授業料未払いの合格校。
  この状態の学校は、授業料を支払って入学を確定できる。
-/
def canPayTuitionState (state : SchoolState) (today : Date) : Bool :=
  isActivePass state ∧
  state.paymentStatus.enrollmentFeePaid ∧
  ¬state.paymentStatus.tuitionPaid ∧
  state.school.tuitionDeadline.day ≥ today.day

/--
  【定理】授業料期限日で上位校が全て消滅していれば授業料支払いが推奨される

  ## 定理の意義
  deadline_forces_payment の授業料版。
  授業料期限日に、上位校が全て不合格または取り消しなら、
  shouldPayTuition は必ず true を返す。

  ## 前提条件
  - h_can_pay: 授業料を支払える状態（合格・入学金払い済み・授業料未払い・期限内）
  - h_deadline: 今日が授業料期限日
  - h_higher_gone: 上位校が全て消滅（不合格または取り消し）

  ## 結論
  shouldPayTuition = true
-/
theorem tuition_deadline_forces_payment
    (states : List SchoolState)
    (target : SchoolState)
    (today : Date)
    (h_can_pay : canPayTuition target today = true)
    (h_deadline : today.day = target.school.tuitionDeadline.day)
    (_h_higher_gone : (states.filter fun s =>
        s.school.priority.higherThan target.school.priority).all
        (fun s => s.passStatus == PassStatus.Failed ∨ s.passStatus == PassStatus.Cancelled) = true) :
    shouldPayTuition states target today = true := by
  unfold shouldPayTuition
  -- canPayTuition target today = true なので if 分岐の else に進む
  split
  · -- ¬canPayTuition の場合 → h_can_pay と矛盾
    rename_i h_not_can_pay
    simp only [h_can_pay, not_true] at h_not_can_pay
  · -- canPayTuition の場合
    -- isDeadlineToday ∨ allHigherPriorityGone を示す
    simp only [beq_iff_eq, h_deadline, true_or, decide_true]

/--
  【定理】最優先の授業料支払い可能校は、期限日に必ず授業料支払いが推奨される

  ## 定理の意義
  highest_viable_unpaid_recommended_on_deadline の授業料版。
  入学金払い済みで授業料未払いの学校のうち、最も優先度が高いものは、
  授業料期限日に必ず支払いが推奨される。

  ## 前提条件
  - best: 入学金払い済み・授業料未払いの合格校
  - h_highest: best より上位に合格校がない

  ## 結論
  best の授業料期限日に shouldPayTuition = true
-/
theorem highest_tuition_payable_recommended_on_deadline
    (states : List SchoolState)
    (best : SchoolState)
    (_h_in_states : best ∈ states)
    (h_pass : isActivePass best = true)
    (h_enrollment_paid : best.paymentStatus.enrollmentFeePaid = true)
    (h_tuition_not_paid : best.paymentStatus.tuitionPaid = false)
    (_h_no_higher_pass : ∀ s ∈ states,
        s.school.priority.higherThan best.school.priority →
        isActivePass s = false) :
    shouldPayTuition states best (Date.mk best.school.tuitionDeadline.day) = true := by
  let today := Date.mk best.school.tuitionDeadline.day

  -- canPayTuition best today = true を示す
  have h_can_pay : canPayTuition best today = true := by
    simp only [canPayTuition, isActivePass, LE.le]
    simp only [decide_eq_true_eq]
    refine ⟨h_pass, h_enrollment_paid, ?_, Nat.le_refl _⟩
    simp only [h_tuition_not_paid]
    decide

  -- 期限日なので isDeadlineToday = true で十分
  unfold shouldPayTuition
  split
  · -- ¬canPayTuition の場合 → h_can_pay と矛盾
    rename_i h_not_can_pay
    exfalso
    exact h_not_can_pay h_can_pay
  · -- canPayTuition の場合
    -- today.day == best.school.tuitionDeadline.day は今日の定義から自明
    -- isDeadlineToday = true を示す
    simp only [decide_eq_true_eq, beq_self_eq_true, true_or]

/--
  【定理】入学金払い済み・授業料未払いの合格校があり、上位校が全て消滅していれば、
  授業料期限日に必ず授業料支払いが推奨される

  ## 定理の意義
  「入学を確定すべき状況で、授業料支払いを見逃さない」ことの保証。

  入学金を払い済みで授業料未払いの合格校があり、
  その学校より上位に合格校がない（全て不合格または取り消し）場合、
  授業料期限日には必ず支払いが推奨される。

  これにより、入学金を払ったのに授業料期限を逃して入学できなくなる、
  という最悪のシナリオを防ぐ。
-/
theorem tuition_payment_not_missed
    (states : List SchoolState)
    (target : SchoolState)
    (h_in_states : target ∈ states)
    (h_pass : isActivePass target = true)
    (h_enrollment_paid : target.paymentStatus.enrollmentFeePaid = true)
    (h_tuition_not_paid : target.paymentStatus.tuitionPaid = false)
    (h_no_higher_active : ∀ s ∈ states,
        s.school.priority.higherThan target.school.priority →
        s.passStatus == PassStatus.Failed ∨ s.passStatus == PassStatus.Cancelled) :
    let deadlineDate := Date.mk target.school.tuitionDeadline.day
    states.any fun s => shouldPayTuition states s deadlineDate = true := by
  let today := Date.mk target.school.tuitionDeadline.day

  have h_can_pay : canPayTuition target today = true := by
    simp only [canPayTuition, isActivePass, LE.le]
    simp only [decide_eq_true_eq]
    refine ⟨h_pass, h_enrollment_paid, ?_, Nat.le_refl _⟩
    simp only [h_tuition_not_paid]
    decide

  have h_higher_gone : (states.filter fun s =>
      s.school.priority.higherThan target.school.priority).all
      (fun s => s.passStatus == PassStatus.Failed ∨ s.passStatus == PassStatus.Cancelled) = true := by
    rw [List.all_eq_true]
    intro s hs
    simp only [List.mem_filter] at hs
    obtain ⟨hs_in, hs_higher⟩ := hs
    simp only [decide_eq_true_eq]
    exact h_no_higher_active s hs_in hs_higher

  have h_result := tuition_deadline_forces_payment states target today h_can_pay rfl h_higher_gone
  simp only [List.any_eq_true, decide_eq_true_eq]
  exact ⟨target, h_in_states, h_result⟩

/-! ## 支払い総額の最小性に関する定理 -/

/--
  支払い総額を計算する関数

  各学校の支払い状況に基づき、実際に支払った金額の合計を算出する。
-/
def totalPaidAmount (states : List SchoolState) : Nat :=
  states.foldl (fun acc s =>
    let enrollment := if s.paymentStatus.enrollmentFeePaid then s.school.enrollmentFee.value else 0
    let tuition := if s.paymentStatus.tuitionPaid then s.school.tuition.value else 0
    acc + enrollment + tuition) 0

/--
  「不要な入学金」の定義

  上位校に入学可能な合格がある場合、下位校の入学金は「不要」である。
  なぜなら、最終的にその学校には入学しないから。
-/
def isUnnecessaryEnrollmentFee (states : List SchoolState) (target : SchoolState) (today : Date) : Bool :=
  -- 上位校に「入学可能な合格」があるかどうか
  let higherPrioritySchools := states.filter fun s =>
    s.school.priority.higherThan target.school.priority
  higherPrioritySchools.any fun s =>
    isActivePass s ∧
    (s.paymentStatus.enrollmentFeePaid ∨ s.school.enrollmentFeeDeadline.day ≥ today.day)

/--
  【定理】推奨に従えば不要な入学金を払わない

  ## 定理の意義
  shouldPayEnrollmentFee が true を返す場合、その入学金は「不要」ではない。
  つまり、推奨に従って入学金を払う場合、その学校に入学する可能性がある。

  これは「不要な支払いを避ける」という最適性の一側面を証明している。
-/
theorem recommendation_avoids_unnecessary_payment
    (states : List SchoolState)
    (target : SchoolState)
    (today : Date)
    (h_recommend : shouldPayEnrollmentFee states target today = true) :
    isUnnecessaryEnrollmentFee states target today = false := by
  unfold isUnnecessaryEnrollmentFee shouldPayEnrollmentFee at *
  simp only [Bool.not_eq_true] at *
  split at h_recommend
  · contradiction
  · split at h_recommend
    · contradiction
    · rename_i h_no_viable
      simp only [Bool.not_eq_true] at h_no_viable
      exact h_no_viable

/--
  【定理】第1志望合格時は即座に支払いが推奨される（最適性の一側面）

  ## 定理の意義
  第1志望に合格した場合、待機する理由がないので即座に入学金を払う。
-/
theorem first_choice_immediate_payment
    (states : List SchoolState)
    (target : SchoolState)
    (today : Date)
    (h_can_pay : canPayEnrollmentFee target today = true)
    (h_first_choice : (states.filter fun s =>
        s.school.priority.higherThan target.school.priority) = []) :
    shouldPayEnrollmentFee states target today = true := by
  unfold shouldPayEnrollmentFee
  simp only [h_can_pay, h_first_choice, List.any_nil, List.isEmpty_nil, ↓reduceIte]
  decide

/--
  【定理】上位校消滅後は次善校の支払いが推奨される

  ## 定理の意義
  上位校が全て消滅した場合、次善校の入学金支払いが推奨される。
-/
theorem higher_gone_triggers_payment
    (states : List SchoolState)
    (target : SchoolState)
    (today : Date)
    (h_can_pay : canPayEnrollmentFee target today = true)
    (h_no_viable : (states.filter fun s =>
        s.school.priority.higherThan target.school.priority).any
        (fun s => isActivePass s ∧ (s.paymentStatus.enrollmentFeePaid ∨
          s.school.enrollmentFeeDeadline.day ≥ today.day)) = false)
    (h_not_empty : (states.filter fun s =>
        s.school.priority.higherThan target.school.priority).isEmpty = false)
    (h_not_deadline : (today.day == target.school.enrollmentFeeDeadline.day) = false)
    (h_all_gone : (states.filter fun s =>
        s.school.priority.higherThan target.school.priority).all
        (fun s => s.passStatus == PassStatus.Failed ∨
                  s.passStatus == PassStatus.Cancelled ∨
                  (isActivePass s ∧ s.paymentStatus.tuitionPaid) ∨
                  (isActivePass s ∧ ¬s.paymentStatus.enrollmentFeePaid ∧
                   s.school.enrollmentFeeDeadline.day < today.day)) = true) :
    shouldPayEnrollmentFee states target today = true := by
  unfold shouldPayEnrollmentFee
  simp only [h_can_pay, h_no_viable, h_not_empty, h_not_deadline, Bool.false_eq_true, ↓reduceIte]
  exact h_all_gone

/-! ## 状態遷移の整合性に関する定理 -/

/--
  【定理】applyRecommendedAction_PayEnrollmentFee は学校情報を変更しない
-/
theorem applyRecommendedAction_enrollmentFee_preserves_school
    (states : List SchoolState)
    (schoolId : Nat)
    (s : SchoolState)
    (h_mem : s ∈ applyRecommendedAction states (.PayEnrollmentFee schoolId)) :
    ∃ original ∈ states, s.school = original.school := by
  simp only [applyRecommendedAction, List.mem_map] at h_mem
  obtain ⟨original, h_orig_mem, h_eq⟩ := h_mem
  refine ⟨original, h_orig_mem, ?_⟩
  by_cases h : (original.school.id == schoolId) = true
  · simp only [h, ↓reduceIte] at h_eq
    rw [← h_eq]
  · simp only [Bool.not_eq_true] at h
    simp only [h, Bool.false_eq_true, ↓reduceIte] at h_eq
    rw [← h_eq]

/--
  【定理】applyRecommendedAction_PayTuition は学校情報を変更しない
-/
theorem applyRecommendedAction_tuition_preserves_school
    (states : List SchoolState)
    (schoolId : Nat)
    (s : SchoolState)
    (h_mem : s ∈ applyRecommendedAction states (.PayTuition schoolId)) :
    ∃ original ∈ states, s.school = original.school := by
  simp only [applyRecommendedAction, List.mem_map] at h_mem
  obtain ⟨original, h_orig_mem, h_eq⟩ := h_mem
  refine ⟨original, h_orig_mem, ?_⟩
  by_cases h : (original.school.id == schoolId) = true
  · simp only [h, ↓reduceIte] at h_eq
    rw [← h_eq]
  · simp only [Bool.not_eq_true] at h
    simp only [h, Bool.false_eq_true, ↓reduceIte] at h_eq
    rw [← h_eq]

/--
  【定理】applyRecommendedAction_PayEnrollmentFee は PassStatus を変更しない
-/
theorem applyRecommendedAction_enrollmentFee_preserves_passStatus
    (states : List SchoolState)
    (schoolId : Nat)
    (s : SchoolState)
    (h_mem : s ∈ applyRecommendedAction states (.PayEnrollmentFee schoolId)) :
    ∃ original ∈ states, s.passStatus = original.passStatus := by
  simp only [applyRecommendedAction, List.mem_map] at h_mem
  obtain ⟨original, h_orig_mem, h_eq⟩ := h_mem
  refine ⟨original, h_orig_mem, ?_⟩
  by_cases h : (original.school.id == schoolId) = true
  · simp only [h, ↓reduceIte] at h_eq
    rw [← h_eq]
  · simp only [Bool.not_eq_true] at h
    simp only [h, Bool.false_eq_true, ↓reduceIte] at h_eq
    rw [← h_eq]

/--
  【定理】applyRecommendedAction_PayTuition は PassStatus を変更しない
-/
theorem applyRecommendedAction_tuition_preserves_passStatus
    (states : List SchoolState)
    (schoolId : Nat)
    (s : SchoolState)
    (h_mem : s ∈ applyRecommendedAction states (.PayTuition schoolId)) :
    ∃ original ∈ states, s.passStatus = original.passStatus := by
  simp only [applyRecommendedAction, List.mem_map] at h_mem
  obtain ⟨original, h_orig_mem, h_eq⟩ := h_mem
  refine ⟨original, h_orig_mem, ?_⟩
  by_cases h : (original.school.id == schoolId) = true
  · simp only [h, ↓reduceIte] at h_eq
    rw [← h_eq]
  · simp only [Bool.not_eq_true] at h
    simp only [h, Bool.false_eq_true, ↓reduceIte] at h_eq
    rw [← h_eq]

/--
  【定理】applyRecommendedAction は PaymentStatus の不変条件を維持する

  ## 定理の意義
  「授業料支払い済み → 入学金支払い済み」という不変条件は維持される。
-/
theorem applyRecommendedAction_maintains_payment_invariant
    (states : List SchoolState)
    (action : PaymentAction)
    (s : SchoolState)
    (_h_mem : s ∈ applyRecommendedAction states action) :
    s.paymentStatus.tuitionPaid = true → s.paymentStatus.enrollmentFeePaid = true := by
  exact s.paymentStatus.tuitionRequiresEnrollment

/--
  【定理】applyRecommendedAction_PayEnrollmentFee は states のサイズを保存する
-/
theorem applyRecommendedAction_enrollmentFee_preserves_length
    (states : List SchoolState)
    (schoolId : Nat) :
    (applyRecommendedAction states (.PayEnrollmentFee schoolId)).length = states.length := by
  simp [applyRecommendedAction, List.length_map]

/--
  【定理】applyRecommendedAction_PayTuition は states のサイズを保存する
-/
theorem applyRecommendedAction_tuition_preserves_length
    (states : List SchoolState)
    (schoolId : Nat) :
    (applyRecommendedAction states (.PayTuition schoolId)).length = states.length := by
  simp [applyRecommendedAction, List.length_map]

/--
  【定理】applyRecommendedAction_DoNothing は states のサイズを保存する
-/
theorem applyRecommendedAction_doNothing_preserves_length
    (states : List SchoolState) :
    (applyRecommendedAction states .DoNothing).length = states.length := by
  simp [applyRecommendedAction]

/--
  【定理】PayEnrollmentFee は授業料状態を維持する

  ## 定理の意義
  入学金支払いアクションは、授業料の支払い状態に影響しない。
-/
theorem applyRecommendedAction_enrollmentFee_preserves_tuition
    (states : List SchoolState)
    (schoolId : Nat)
    (s : SchoolState)
    (h_mem : s ∈ applyRecommendedAction states (.PayEnrollmentFee schoolId)) :
    ∃ original ∈ states, s.paymentStatus.tuitionPaid = original.paymentStatus.tuitionPaid := by
  simp only [applyRecommendedAction, List.mem_map] at h_mem
  obtain ⟨original, h_orig_mem, h_eq⟩ := h_mem
  refine ⟨original, h_orig_mem, ?_⟩
  by_cases h : (original.school.id == schoolId) = true
  · simp only [h, ↓reduceIte] at h_eq
    rw [← h_eq]
    simp [mkPaymentStatus]
  · simp only [Bool.not_eq_true] at h
    simp only [h, Bool.false_eq_true, ↓reduceIte] at h_eq
    rw [← h_eq]

/--
  【定理】PayTuition は入学金も支払い済みにする

  ## 定理の意義
  授業料支払いアクションを実行すると、入学金も支払い済みになる。
-/
theorem applyRecommendedAction_tuition_sets_both
    (states : List SchoolState)
    (schoolId : Nat)
    (s : SchoolState)
    (h_mem : s ∈ applyRecommendedAction states (.PayTuition schoolId))
    (h_id : s.school.id = schoolId) :
    s.paymentStatus.enrollmentFeePaid = true ∧ s.paymentStatus.tuitionPaid = true := by
  simp only [applyRecommendedAction, List.mem_map] at h_mem
  obtain ⟨original, _, h_eq⟩ := h_mem
  by_cases h : (original.school.id == schoolId) = true
  · simp only [h, ↓reduceIte] at h_eq
    rw [← h_eq]
    simp [mkPaymentStatus]
  · simp only [Bool.not_eq_true] at h
    simp only [h, Bool.false_eq_true, ↓reduceIte] at h_eq
    rw [← h_eq] at h_id
    simp only [beq_eq_false_iff_ne, ne_eq] at h
    exact absurd h_id h

/--
  【定理】PayEnrollmentFee は他の学校の状態を変更しない
-/
theorem applyRecommendedAction_enrollmentFee_preserves_other_schools
    (states : List SchoolState)
    (schoolId : Nat)
    (original : SchoolState)
    (h_orig_mem : original ∈ states)
    (h_not_target : original.school.id ≠ schoolId) :
    ∃ s' ∈ applyRecommendedAction states (.PayEnrollmentFee schoolId), s' = original := by
  refine ⟨original, ?_, rfl⟩
  simp only [applyRecommendedAction, List.mem_map]
  refine ⟨original, h_orig_mem, ?_⟩
  have h_ne : (original.school.id == schoolId) = false := by
    simp only [beq_eq_false_iff_ne, ne_eq]
    exact h_not_target
  simp only [h_ne, Bool.false_eq_true, ↓reduceIte]

/--
  【定理】PayTuition は他の学校の状態を変更しない
-/
theorem applyRecommendedAction_tuition_preserves_other_schools
    (states : List SchoolState)
    (schoolId : Nat)
    (original : SchoolState)
    (h_orig_mem : original ∈ states)
    (h_not_target : original.school.id ≠ schoolId) :
    ∃ s' ∈ applyRecommendedAction states (.PayTuition schoolId), s' = original := by
  refine ⟨original, ?_, rfl⟩
  simp only [applyRecommendedAction, List.mem_map]
  refine ⟨original, h_orig_mem, ?_⟩
  have h_ne : (original.school.id == schoolId) = false := by
    simp only [beq_eq_false_iff_ne, ne_eq]
    exact h_not_target
  simp only [h_ne, Bool.false_eq_true, ↓reduceIte]

end SchoolPayment
