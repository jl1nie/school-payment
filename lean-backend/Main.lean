/-
  Main.lean

  志望校支払いアドバイザー REPLサーバー

  使用方法:
  - `lake exe advisor` : サンプル実行
  - `lake exe advisor --repl` : REPLモード（JSON-RPC over stdin/stdout）
-/

import SchoolPayment

open SchoolPayment

/-- サンプルデータでのデモ実行 -/
def runDemo : IO Unit := do
  IO.println "=== 志望校支払いアドバイザー デモ ==="
  IO.println ""

  -- サンプルリクエスト（Day 28 = 明治の入学金期限日）
  let sampleRequest := "{\"jsonrpc\":\"2.0\",\"method\":\"getRecommendation\",\"params\":{\"today\":28,\"schools\":[{\"id\":1,\"name\":\"東京大学\",\"priority\":1,\"examDate\":25,\"resultDate\":40,\"enrollmentFeeDeadline\":45,\"tuitionDeadline\":60,\"enrollmentFee\":282000,\"tuition\":535800},{\"id\":2,\"name\":\"早稲田大学\",\"priority\":2,\"examDate\":12,\"resultDate\":20,\"enrollmentFeeDeadline\":35,\"tuitionDeadline\":50,\"enrollmentFee\":200000,\"tuition\":1000000},{\"id\":3,\"name\":\"明治大学\",\"priority\":3,\"examDate\":5,\"resultDate\":10,\"enrollmentFeeDeadline\":28,\"tuitionDeadline\":45,\"enrollmentFee\":250000,\"tuition\":800000}],\"states\":[{\"schoolId\":1,\"passStatus\":\"notYetAnnounced\",\"enrollmentFeePaid\":false,\"tuitionPaid\":false},{\"schoolId\":2,\"passStatus\":\"passed\",\"enrollmentFeePaid\":false,\"tuitionPaid\":false},{\"schoolId\":3,\"passStatus\":\"passed\",\"enrollmentFeePaid\":false,\"tuitionPaid\":false}]},\"id\":1}"

  IO.println "リクエスト:"
  IO.println sampleRequest
  IO.println ""
  IO.println "レスポンス:"
  let response := processJsonRpc sampleRequest
  IO.println response
  IO.println ""

  -- シナリオ2: 待機推奨
  IO.println "=== シナリオ2: 待機推奨（Day 30）==="
  let waitRequest := "{\"jsonrpc\":\"2.0\",\"method\":\"getRecommendation\",\"params\":{\"today\":30,\"schools\":[{\"id\":1,\"name\":\"東京大学\",\"priority\":1,\"examDate\":25,\"resultDate\":40,\"enrollmentFeeDeadline\":45,\"tuitionDeadline\":60,\"enrollmentFee\":282000,\"tuition\":535800},{\"id\":2,\"name\":\"早稲田大学\",\"priority\":2,\"examDate\":12,\"resultDate\":20,\"enrollmentFeeDeadline\":35,\"tuitionDeadline\":50,\"enrollmentFee\":200000,\"tuition\":1000000}],\"states\":[{\"schoolId\":1,\"passStatus\":\"notYetAnnounced\",\"enrollmentFeePaid\":false,\"tuitionPaid\":false},{\"schoolId\":2,\"passStatus\":\"passed\",\"enrollmentFeePaid\":false,\"tuitionPaid\":false}]},\"id\":2}"

  IO.println "レスポンス:"
  let response2 := processJsonRpc waitRequest
  IO.println response2

/-- REPLモード: 標準入力から1行ずつ読み取り処理 -/
def runRepl : IO Unit := do
  IO.println "{\"jsonrpc\":\"2.0\",\"result\":\"ready\",\"id\":0}"
  (← IO.getStdout).flush

  let stdin ← IO.getStdin
  let stdout ← IO.getStdout

  while true do
    let line ← stdin.getLine
    if line.isEmpty then
      break
    let trimmed := line.trimAscii.toString
    if trimmed.isEmpty then
      continue
    let response := processJsonRpc trimmed
    stdout.putStrLn response
    stdout.flush

/-- メインエントリポイント -/
def main (args : List String) : IO Unit := do
  if args.contains "--repl" then
    runRepl
  else
    runDemo
