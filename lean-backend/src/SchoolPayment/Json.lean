/-
  SchoolPayment/Json.lean

  JSONシリアライズ/デシリアライズの実装

  【このファイルの目的】
  フロントエンド（TypeScript）との通信のため、
  全てのドメイン型に対してJSONの変換機能を提供する。

  【設計思想】
  - ToJson: Lean型 → JSON（レスポンス用）
  - FromJson: JSON → Lean型（リクエスト用）
  - 証明付き型の変換時は制約の検証/構築を行う

  【注意点】
  - FromJson は Except String を返し、パースエラーを明示的に扱う
  - 証明付き型の構築時は、制約違反の場合にエラーを返す
-/

import SchoolPayment.Types
import SchoolPayment.Strategy
import Lean.Data.Json

namespace SchoolPayment

open Lean Json

/-! ## ToJson インスタンス（Lean → JSON）-/

/-- Date はYYYYMMDD形式の整数としてシリアライズ -/
instance : ToJson Date where
  toJson d := toJson d.day

/-- Amount も値（Nat）としてシリアライズ -/
instance : ToJson Amount where
  toJson a := toJson a.value

/-- Priority は rank（Nat）としてシリアライズ -/
instance : ToJson Priority where
  toJson p := toJson p.rank

/--
  PassStatus は文字列としてシリアライズ

  - NotYetAnnounced → "notYetAnnounced"
  - Passed → "passed"
  - Failed → "failed"
  - Cancelled → "cancelled"
-/
instance : ToJson PassStatus where
  toJson
    | .NotYetAnnounced => "notYetAnnounced"
    | .Passed => "passed"
    | .Failed => "failed"
    | .Cancelled => "cancelled"

/-- PaymentStatus はオブジェクトとしてシリアライズ -/
instance : ToJson PaymentStatus where
  toJson ps := Json.mkObj [
    ("enrollmentFeePaid", toJson ps.enrollmentFeePaid),
    ("tuitionPaid", toJson ps.tuitionPaid)
  ]

/--
  School はオブジェクトとしてシリアライズ

  証明フィールドは含まない（フロントエンドには不要）
-/
instance : ToJson School where
  toJson s := Json.mkObj [
    ("id", toJson s.id),
    ("name", toJson s.name),
    ("priority", toJson s.priority),
    ("examDate", toJson s.examDate),
    ("resultDate", toJson s.resultDate),
    ("enrollmentFeeDeadline", toJson s.enrollmentFeeDeadline),
    ("tuitionDeadline", toJson s.tuitionDeadline),
    ("enrollmentFee", toJson s.enrollmentFee),
    ("tuition", toJson s.tuition)
  ]

/-- SchoolState はネストしたオブジェクトとしてシリアライズ -/
instance : ToJson SchoolState where
  toJson ss := Json.mkObj [
    ("school", toJson ss.school),
    ("passStatus", toJson ss.passStatus),
    ("paymentStatus", toJson ss.paymentStatus)
  ]

/--
  PaymentAction はタグ付きオブジェクトとしてシリアライズ

  - PayEnrollmentFee → {"type": "payEnrollmentFee", "schoolId": N}
  - PayTuition → {"type": "payTuition", "schoolId": N}
  - DoNothing → {"type": "doNothing"}
-/
instance : ToJson PaymentAction where
  toJson
    | .PayEnrollmentFee id => Json.mkObj [
        ("type", "payEnrollmentFee"),
        ("schoolId", toJson id)
      ]
    | .PayTuition id => Json.mkObj [
        ("type", "payTuition"),
        ("schoolId", toJson id)
      ]
    | .DoNothing => Json.mkObj [
        ("type", "doNothing")
      ]

/-- Recommendation はオブジェクトとしてシリアライズ -/
instance : ToJson Recommendation where
  toJson r := Json.mkObj [
    ("action", toJson r.action),
    ("reason", toJson r.reason),
    ("urgency", toJson r.urgency)
  ]

/-! ## FromJson インスタンス（JSON → Lean）-/

/-- Date のパース（YYYYMMDD形式のNatから構築） -/
instance : FromJson Date where
  fromJson? j := do
    let day ← j.getNat?
    return ⟨day⟩

/--
  Amount のパース（正値制約をチェック）

  0 以下の値が渡された場合はエラーを返す。
-/
instance : FromJson Amount where
  fromJson? j := do
    let value ← j.getNat?
    if h : value > 0 then
      return ⟨value, h⟩
    else
      throw "Amount must be positive"

/--
  Priority のパース（正値制約をチェック）

  0 以下の値が渡された場合はエラーを返す。
-/
instance : FromJson Priority where
  fromJson? j := do
    let rank ← j.getNat?
    if h : rank > 0 then
      return ⟨rank, h⟩
    else
      throw "Priority rank must be positive"

/--
  PassStatus のパース（文字列から列挙型へ）

  未知の文字列が渡された場合はエラーを返す。
-/
instance : FromJson PassStatus where
  fromJson? j := do
    let s ← j.getStr?
    match s with
    | "notYetAnnounced" => return .NotYetAnnounced
    | "passed" => return .Passed
    | "failed" => return .Failed
    | "cancelled" => return .Cancelled
    | _ => throw s!"Unknown pass status: {s}"

/-! ## PaymentStatus のパース -/

-- mkPaymentStatus は Types.lean で定義

/--
  PaymentStatus のパース

  mkPaymentStatus を使用して安全に構築。
-/
instance : FromJson PaymentStatus where
  fromJson? j := do
    let enrollmentFeePaid ← j.getObjValAs? Bool "enrollmentFeePaid"
    let tuitionPaid ← j.getObjValAs? Bool "tuitionPaid"
    return mkPaymentStatus enrollmentFeePaid tuitionPaid

/-! ## School のパース（証明付き制約の検証） -/

/--
  School をパースする（証明付き制約のため複雑）

  【検証する制約】
  1. tuition > enrollmentFee（授業料 > 入学金）
  2. resultDate ≥ examDate（発表日 ≥ 受験日）
  3. enrollmentFeeDeadline ≥ resultDate（入学金期限 ≥ 発表日）
  4. tuitionDeadline ≥ enrollmentFeeDeadline（授業料期限 ≥ 入学金期限）

  各制約が満たされない場合、明確なエラーメッセージを返す。
-/
def parseSchool (j : Json) : Except String School := do
  let id ← j.getObjValAs? Nat "id"
  let name ← j.getObjValAs? String "name"
  let priority ← j.getObjValAs? Priority "priority"
  let examDate ← j.getObjValAs? Date "examDate"
  let resultDate ← j.getObjValAs? Date "resultDate"
  let enrollmentFeeDeadline ← j.getObjValAs? Date "enrollmentFeeDeadline"
  let tuitionDeadline ← j.getObjValAs? Date "tuitionDeadline"
  let enrollmentFee ← j.getObjValAs? Amount "enrollmentFee"
  let tuition ← j.getObjValAs? Amount "tuition"

  -- 制約の検証（各条件が if で分岐し、証明を構築）
  if h1 : tuition.value > enrollmentFee.value then
    if h2 : resultDate.day ≥ examDate.day then
      if h3 : enrollmentFeeDeadline.day ≥ resultDate.day then
        if h4 : tuitionDeadline.day ≥ enrollmentFeeDeadline.day then
          return {
            id, name, priority, examDate, resultDate,
            enrollmentFeeDeadline, tuitionDeadline,
            enrollmentFee, tuition,
            tuitionHigherThanFee := h1,
            resultAfterExam := h2,
            feeDeadlineAfterResult := h3,
            tuitionAfterFee := h4
          }
        else
          throw "tuitionDeadline must be >= enrollmentFeeDeadline"
      else
        throw "enrollmentFeeDeadline must be >= resultDate"
    else
      throw "resultDate must be >= examDate"
  else
    throw "tuition must be > enrollmentFee"

instance : FromJson School where
  fromJson? := parseSchool

/-- SchoolState をパースする -/
def parseSchoolState (j : Json) : Except String SchoolState := do
  let school ← j.getObjValAs? School "school"
  let passStatus ← j.getObjValAs? PassStatus "passStatus"
  let paymentStatus ← j.getObjValAs? PaymentStatus "paymentStatus"
  return ⟨school, passStatus, paymentStatus⟩

instance : FromJson SchoolState where
  fromJson? := parseSchoolState

/-! ## 簡易入力形式（フロントエンド向け） -/

/--
  フロントエンドからの簡易入力形式: 学校情報

  School 型は証明付き制約があるため直接パースが複雑。
  この構造体は制約なしの「生データ」を受け取り、
  後から検証して School に変換する。
-/
structure SchoolInput where
  id : Nat
  name : String
  priority : Nat
  examDate : Nat
  resultDate : Nat
  enrollmentFeeDeadline : Nat
  tuitionDeadline : Nat
  enrollmentFee : Nat
  tuition : Nat
deriving Repr

/--
  フロントエンドからの簡易入力形式: 状態情報

  SchoolInput と紐づく状態情報。
  schoolId で対応する学校を識別する。
-/
structure StateInput where
  schoolId : Nat
  passStatus : String
  enrollmentFeePaid : Bool
  tuitionPaid : Bool
deriving Repr

instance : FromJson SchoolInput where
  fromJson? j := do
    let id ← j.getObjValAs? Nat "id"
    let name ← j.getObjValAs? String "name"
    let priority ← j.getObjValAs? Nat "priority"
    let examDate ← j.getObjValAs? Nat "examDate"
    let resultDate ← j.getObjValAs? Nat "resultDate"
    let enrollmentFeeDeadline ← j.getObjValAs? Nat "enrollmentFeeDeadline"
    let tuitionDeadline ← j.getObjValAs? Nat "tuitionDeadline"
    let enrollmentFee ← j.getObjValAs? Nat "enrollmentFee"
    let tuition ← j.getObjValAs? Nat "tuition"
    return ⟨id, name, priority, examDate, resultDate, enrollmentFeeDeadline, tuitionDeadline, enrollmentFee, tuition⟩

instance : FromJson StateInput where
  fromJson? j := do
    let schoolId ← j.getObjValAs? Nat "schoolId"
    let passStatus ← j.getObjValAs? String "passStatus"
    let enrollmentFeePaid ← j.getObjValAs? Bool "enrollmentFeePaid"
    let tuitionPaid ← j.getObjValAs? Bool "tuitionPaid"
    return ⟨schoolId, passStatus, enrollmentFeePaid, tuitionPaid⟩

/--
  PassStatus の文字列からの変換（エラーを返さない版）

  未知の文字列の場合は NotYetAnnounced をデフォルトとする。
-/
def parsePassStatusStr (s : String) : PassStatus :=
  match s with
  | "notYetAnnounced" => .NotYetAnnounced
  | "passed" => .Passed
  | "failed" => .Failed
  | "cancelled" => .Cancelled
  | _ => .NotYetAnnounced  -- デフォルト

/--
  SchoolInput から School を構築（失敗する可能性あり）

  全ての制約を検証し、満たされない場合はエラーを返す。
-/
def schoolInputToSchool (si : SchoolInput) : Except String School := do
  -- 正値チェック
  if h_prio : si.priority > 0 then
    if h_fee : si.enrollmentFee > 0 then
      if h_tui : si.tuition > 0 then
        -- 制約チェック
        if h1 : si.tuition > si.enrollmentFee then
          if h2 : si.resultDate ≥ si.examDate then
            if h3 : si.enrollmentFeeDeadline ≥ si.resultDate then
              if h4 : si.tuitionDeadline ≥ si.enrollmentFeeDeadline then
                return {
                  id := si.id,
                  name := si.name,
                  priority := ⟨si.priority, h_prio⟩,
                  examDate := ⟨si.examDate⟩,
                  resultDate := ⟨si.resultDate⟩,
                  enrollmentFeeDeadline := ⟨si.enrollmentFeeDeadline⟩,
                  tuitionDeadline := ⟨si.tuitionDeadline⟩,
                  enrollmentFee := ⟨si.enrollmentFee, h_fee⟩,
                  tuition := ⟨si.tuition, h_tui⟩,
                  tuitionHigherThanFee := h1,
                  resultAfterExam := h2,
                  feeDeadlineAfterResult := h3,
                  tuitionAfterFee := h4
                }
              else throw s!"School {si.name}: tuitionDeadline must be >= enrollmentFeeDeadline"
            else throw s!"School {si.name}: enrollmentFeeDeadline must be >= resultDate"
          else throw s!"School {si.name}: resultDate must be >= examDate"
        else throw s!"School {si.name}: tuition must be > enrollmentFee"
      else throw s!"School {si.name}: tuition must be positive"
    else throw s!"School {si.name}: enrollmentFee must be positive"
  else throw s!"School {si.name}: priority must be positive"

/--
  School と StateInput から SchoolState を構築

  mkPaymentStatus を使用して安全に PaymentStatus を構築。
-/
def buildSchoolState (school : School) (stateInput : StateInput) : SchoolState :=
  {
    school := school,
    passStatus := parsePassStatusStr stateInput.passStatus,
    paymentStatus := mkPaymentStatus stateInput.enrollmentFeePaid stateInput.tuitionPaid
  }

end SchoolPayment
