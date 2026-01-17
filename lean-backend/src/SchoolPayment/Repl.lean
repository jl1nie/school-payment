/-
  SchoolPayment/Repl.lean

  JSON-RPC通信処理

  【このファイルの目的】
  フロントエンド（TypeScript）との通信層を実装する。
  標準入力からJSONリクエストを受け取り、
  処理結果をJSONレスポンスとして標準出力に返す。

  【プロトコル】
  JSON-RPC 2.0 に準拠
  - リクエスト: {"jsonrpc": "2.0", "method": "...", "params": {...}, "id": N}
  - レスポンス: {"jsonrpc": "2.0", "result": {...}, "id": N}
  - エラー: {"jsonrpc": "2.0", "error": {...}, "id": N}

  【サポートするメソッド】
  - getRecommendation: 支払い推奨アクションを取得
  - ping: 接続確認（"pong"を返す）
-/

import SchoolPayment.Types
import SchoolPayment.Rules
import SchoolPayment.Strategy
import SchoolPayment.Json
import Lean.Data.Json

namespace SchoolPayment

open Lean Json

/-! ## JSON-RPC リクエスト/レスポンス型 -/

/--
  JSON-RPC リクエストの構造

  JSON-RPC 2.0 仕様に準拠:
  - jsonrpc: バージョン文字列（"2.0"）
  - method: 呼び出すメソッド名
  - params: メソッドのパラメータ（JSON値）
  - id: リクエストID（レスポンスと対応付けに使用）
-/
structure JsonRpcRequest where
  jsonrpc : String
  method : String
  params : Json
  id : Nat

/--
  JSON-RPC レスポンスの構造

  成功時は result フィールド、エラー時は error フィールドを設定。
  両方同時に設定されることはない。
-/
structure JsonRpcResponse where
  jsonrpc : String := "2.0"
  result : Option Json := none
  error : Option Json := none
  id : Nat

/-- JsonRpcRequest のパース -/
instance : FromJson JsonRpcRequest where
  fromJson? j := do
    let jsonrpc ← j.getObjValAs? String "jsonrpc"
    let method ← j.getObjValAs? String "method"
    let params ← j.getObjVal? "params"
    let id ← j.getObjValAs? Nat "id"
    return ⟨jsonrpc, method, params, id⟩

/-- JsonRpcResponse のシリアライズ -/
instance : ToJson JsonRpcResponse where
  toJson r :=
    let base := [("jsonrpc", toJson r.jsonrpc), ("id", toJson r.id)]
    let withResult := match r.result with
      | some res => base ++ [("result", res)]
      | none => base
    let withError := match r.error with
      | some err => withResult ++ [("error", err)]
      | none => withResult
    Json.mkObj withError

/-! ## レスポンス構造体 -/

/--
  getRecommendation メソッドのレスポンス

  - action: 最も推奨されるアクション
  - reason: 推奨理由（ユーザー向けメッセージ）
  - urgency: 緊急度（0が最も緊急）
  - allRecommendations: 全ての推奨アクションのリスト
-/
structure GetRecommendationResult where
  action : PaymentAction
  reason : String
  urgency : Nat
  allRecommendations : List Recommendation
deriving Repr

instance : ToJson GetRecommendationResult where
  toJson r := Json.mkObj [
    ("action", toJson r.action),
    ("reason", toJson r.reason),
    ("urgency", toJson r.urgency),
    ("allRecommendations", toJson r.allRecommendations)
  ]

/--
  1日分の推奨アクション（日付情報付き）
-/
structure DailyRecommendation where
  day : Nat
  result : GetRecommendationResult
deriving Repr

instance : ToJson DailyRecommendation where
  toJson r := Json.mkObj [
    ("day", toJson r.day),
    ("result", toJson r.result)
  ]

/--
  発表予定の学校情報
-/
structure UpcomingAnnouncement where
  schoolId : Nat
  schoolName : String
  resultDay : Nat
deriving Repr

instance : ToJson UpcomingAnnouncement where
  toJson a := Json.mkObj [
    ("schoolId", toJson a.schoolId),
    ("schoolName", toJson a.schoolName),
    ("resultDay", toJson a.resultDay)
  ]

/--
  getWeeklyRecommendations メソッドのレスポンス

  - startDay: 開始日（Day番号）
  - recommendations: 各日の推奨アクション
  - upcomingAnnouncements: 期間内の発表予定
  - note: 発表により状況が変わる可能性がある場合の注記
-/
structure GetWeeklyRecommendationsResult where
  startDay : Nat
  recommendations : List DailyRecommendation
  upcomingAnnouncements : List UpcomingAnnouncement
  note : Option String
deriving Repr

instance : ToJson GetWeeklyRecommendationsResult where
  toJson r := Json.mkObj [
    ("startDay", toJson r.startDay),
    ("recommendations", toJson r.recommendations),
    ("upcomingAnnouncements", toJson r.upcomingAnnouncements),
    ("note", match r.note with | some n => toJson n | none => Json.null)
  ]

/-! ## RPC メソッド実装 -/

/--
  getRecommendation メソッドのパラメータ

  - today: 現在の日付（Day番号）
  - schools: 学校情報の配列
  - states: 各学校の状態の配列
-/
structure GetRecommendationParams where
  today : Nat
  schools : Array SchoolInput
  states : Array StateInput
deriving Repr

instance : FromJson GetRecommendationParams where
  fromJson? j := do
    let today ← j.getObjValAs? Nat "today"
    let schools ← j.getObjValAs? (Array SchoolInput) "schools"
    let states ← j.getObjValAs? (Array StateInput) "states"
    return ⟨today, schools, states⟩

/--
  getWeeklyRecommendations メソッドのパラメータ

  - startDay: 開始日（Day番号）
  - days: 何日分取得するか（デフォルト7）
  - schools: 学校情報の配列
  - states: 各学校の状態の配列
-/
structure GetWeeklyRecommendationsParams where
  startDay : Nat
  days : Nat := 7
  schools : Array SchoolInput
  states : Array StateInput
deriving Repr

instance : FromJson GetWeeklyRecommendationsParams where
  fromJson? j := do
    let startDay ← j.getObjValAs? Nat "startDay"
    let days := (j.getObjValAs? Nat "days").toOption.getD 7
    let schools ← j.getObjValAs? (Array SchoolInput) "schools"
    let states ← j.getObjValAs? (Array StateInput) "states"
    return ⟨startDay, days, schools, states⟩

/--
  入力データを SchoolState のリストに変換

  【処理】
  1. 各 SchoolInput を School に変換（制約検証）
  2. 対応する StateInput を見つける
  3. SchoolState を構築

  対応する state がない場合はデフォルト状態（未発表・未払い）を使用。
-/
def buildSchoolStates (schools : Array SchoolInput) (states : Array StateInput) : Except String (List SchoolState) := do
  let mut result : List SchoolState := []
  for si in schools do
    let school ← schoolInputToSchool si
    -- 対応するstateを探す
    match states.find? (fun st => st.schoolId == si.id) with
    | some stateInput =>
      let schoolState := buildSchoolState school stateInput
      result := result ++ [schoolState]
    | none =>
      -- stateがない場合はデフォルト状態
      let schoolState : SchoolState := {
        school := school,
        passStatus := .NotYetAnnounced,
        paymentStatus := mkPaymentStatus false false
      }
      result := result ++ [schoolState]
  return result

/--
  期限切れによる状態更新を適用

  全ての学校に対して updateStatusOnDeadline を適用し、
  期限切れの学校を Cancelled 状態に更新する。
-/
def applyDeadlineUpdates (states : List SchoolState) (today : Date) : List SchoolState :=
  states.map (fun s => updateStatusOnDeadline s today)

/--
  合否状況と発表日の整合性をバリデーション

  - 発表日より前に Passed/Failed が設定されている場合はエラー
  - 発表日以降に NotYetAnnounced のままの場合はエラー
-/
def validatePassStatusTiming (states : List SchoolState) (today : Date) : Except String Unit := do
  for s in states do
    -- 発表日前に合否が設定されている
    if (s.passStatus == PassStatus.Passed || s.passStatus == PassStatus.Failed) &&
       today.day < s.school.resultDate.day then
      throw s!"エラー: {s.school.name}の発表日（{s.school.resultDate.day}）より前に合否が設定されています"
    -- 発表日後なのに未発表のまま
    if s.passStatus == PassStatus.NotYetAnnounced &&
       today.day >= s.school.resultDate.day then
      throw s!"エラー: {s.school.name}の発表日（{s.school.resultDate.day}）を過ぎていますが、合否が入力されていません"
  return ()

/--
  getRecommendation の実行

  【処理フロー】
  1. パラメータから SchoolState リストを構築
  2. 期限切れの状態更新を適用
  3. 推奨アクションを計算
  4. 結果を返す
-/
def executeGetRecommendation (params : GetRecommendationParams) : Except String GetRecommendationResult := do
  let today : Date := ⟨params.today⟩
  let schoolStates ← buildSchoolStates params.schools params.states
  -- 発表日前の合否設定をバリデーション
  validatePassStatusTiming schoolStates today
  -- 期限切れの状態更新を適用
  let updatedStates := applyDeadlineUpdates schoolStates today
  -- 推奨アクションを取得
  let topRec := getTopRecommendation updatedStates today
  let allRecs := getAllRecommendations updatedStates today
  return {
    action := topRec.action,
    reason := topRec.reason,
    urgency := topRec.urgency,
    allRecommendations := allRecs
  }

/--
  getWeeklyRecommendations の実行

  【処理フロー】
  1. パラメータから SchoolState リストを構築
  2. 各日について推奨アクションを計算
  3. 期間内の発表予定を収集
  4. 結果を返す
-/
def executeGetWeeklyRecommendations (params : GetWeeklyRecommendationsParams) : Except String GetWeeklyRecommendationsResult := do
  let schoolStates ← buildSchoolStates params.schools params.states
  let startDate : Date := ⟨params.startDay⟩
  -- 発表日前の合否設定をバリデーション（開始日時点でチェック）
  validatePassStatusTiming schoolStates startDate

  -- 各日の推奨を計算
  let mut dailyRecs : List DailyRecommendation := []
  for i in [:params.days] do
    let today := startDate.addDays i
    let day := today.day
    let updatedStates := applyDeadlineUpdates schoolStates today
    let topRec := getTopRecommendation updatedStates today
    let allRecs := getAllRecommendations updatedStates today
    -- urgencyは基準日（startDay）から見た残り日数に変換
    let urgencyFromBase := day - params.startDay
    let adjustedAllRecs := allRecs.map fun r => { r with urgency := urgencyFromBase }
    let result : GetRecommendationResult := {
      action := topRec.action,
      reason := topRec.reason,
      urgency := urgencyFromBase,
      allRecommendations := adjustedAllRecs
    }
    dailyRecs := dailyRecs ++ [{ day := day, result := result }]

  -- 期間内の発表予定を収集（未発表の学校のうち、発表日が期間内のもの）
  let endDate := startDate.addDays (params.days - 1)
  let endDay := endDate.day
  let upcomingAnnouncements : List UpcomingAnnouncement := schoolStates.filterMap fun s =>
    if s.passStatus == PassStatus.NotYetAnnounced &&
       s.school.resultDate.day ≥ params.startDay &&
       s.school.resultDate.day ≤ endDay then
      some {
        schoolId := s.school.id,
        schoolName := s.school.name,
        resultDay := s.school.resultDate.day
      }
    else
      none

  -- 注記を生成
  let note := if upcomingAnnouncements.isEmpty then
    none
  else
    some "この期間中に合格発表がある学校があります。発表結果により推奨アクションが変わる可能性があります。"

  return {
    startDay := params.startDay,
    recommendations := dailyRecs,
    upcomingAnnouncements := upcomingAnnouncements,
    note := note
  }

/-! ## エラーコード（JSON-RPC 2.0 標準） -/

/-- パースエラー（不正なJSON） -/
def errorParseError : Json := Json.mkObj [
  ("code", toJson (-32700 : Int)),
  ("message", "Parse error")
]

/-- 無効なリクエスト（JSON-RPCとして不正） -/
def errorInvalidRequest : Json := Json.mkObj [
  ("code", toJson (-32600 : Int)),
  ("message", "Invalid Request")
]

/-- メソッドが見つからない -/
def errorMethodNotFound (method : String) : Json := Json.mkObj [
  ("code", toJson (-32601 : Int)),
  ("message", s!"Method not found: {method}")
]

/-- 無効なパラメータ -/
def errorInvalidParams (msg : String) : Json := Json.mkObj [
  ("code", toJson (-32602 : Int)),
  ("message", s!"Invalid params: {msg}")
]

/-- 内部エラー -/
def errorInternal (msg : String) : Json := Json.mkObj [
  ("code", toJson (-32603 : Int)),
  ("message", s!"Internal error: {msg}")
]

/-! ## リクエスト処理 -/

/--
  単一のJSON-RPCリクエストを処理

  【処理フロー】
  1. jsonrpc バージョンの検証
  2. メソッド名でディスパッチ
  3. パラメータのパースと実行
  4. 結果またはエラーをレスポンスとして返す
-/
def handleRequest (req : JsonRpcRequest) : JsonRpcResponse :=
  if req.jsonrpc != "2.0" then
    { id := req.id, error := some errorInvalidRequest }
  else
    match req.method with
    | "getRecommendation" =>
      match FromJson.fromJson? req.params with
      | Except.ok (params : GetRecommendationParams) =>
        match executeGetRecommendation params with
        | Except.ok result => { id := req.id, result := some (toJson result) }
        | Except.error msg => { id := req.id, error := some (errorInvalidParams msg) }
      | Except.error msg => { id := req.id, error := some (errorInvalidParams msg) }
    | "getWeeklyRecommendations" =>
      match FromJson.fromJson? req.params with
      | Except.ok (params : GetWeeklyRecommendationsParams) =>
        match executeGetWeeklyRecommendations params with
        | Except.ok result => { id := req.id, result := some (toJson result) }
        | Except.error msg => { id := req.id, error := some (errorInvalidParams msg) }
      | Except.error msg => { id := req.id, error := some (errorInvalidParams msg) }
    | "ping" =>
      { id := req.id, result := some (toJson "pong") }
    | method =>
      { id := req.id, error := some (errorMethodNotFound method) }

/--
  JSON文字列をパースしてリクエストを処理

  【エントリポイント】
  Main.lean から呼び出される。
  生のJSON文字列を受け取り、処理結果をJSON文字列で返す。
-/
def processJsonRpc (input : String) : String :=
  match Json.parse input with
  | Except.error _ =>
    let resp : JsonRpcResponse := { id := 0, error := some errorParseError }
    toString (toJson resp)
  | Except.ok json =>
    match FromJson.fromJson? json with
    | Except.error _ =>
      let resp : JsonRpcResponse := { id := 0, error := some errorInvalidRequest }
      toString (toJson resp)
    | Except.ok (req : JsonRpcRequest) =>
      let resp := handleRequest req
      toString (toJson resp)

end SchoolPayment
