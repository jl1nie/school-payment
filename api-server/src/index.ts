import express from "express";
import cors from "cors";
import { spawn, ChildProcess } from "child_process";
import path from "path";

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

// Lean REPL プロセス管理
let leanProcess: ChildProcess | null = null;
let responseBuffer = "";
let currentResolve: ((value: string) => void) | null = null;
let currentReject: ((reason: Error) => void) | null = null;

const LEAN_BACKEND_PATH = process.env.LEAN_BACKEND_PATH || path.resolve(__dirname, "../../lean-backend");
const ADVISOR_BIN = path.join(LEAN_BACKEND_PATH, ".lake", "build", "bin", "advisor");

function startLeanRepl(): Promise<void> {
  return new Promise((resolve, reject) => {
    console.log("Starting Lean REPL...");
    console.log("Binary:", ADVISOR_BIN);

    leanProcess = spawn(ADVISOR_BIN, ["--repl"], {
      stdio: ["pipe", "pipe", "pipe"],
    });

    leanProcess.stdout?.on("data", (data: Buffer) => {
      const text = data.toString();
      responseBuffer += text;

      // 完全なJSONオブジェクトを抽出する
      // Lean REPLは複数行のフォーマット済みJSONを出力するため、
      // 括弧のバランスで完全性を判定
      while (responseBuffer.length > 0) {
        const startIdx = responseBuffer.indexOf("{");
        if (startIdx === -1) {
          responseBuffer = "";
          break;
        }

        // 括弧のバランスをチェック
        let depth = 0;
        let inString = false;
        let escape = false;
        let endIdx = -1;

        for (let i = startIdx; i < responseBuffer.length; i++) {
          const c = responseBuffer[i];
          if (escape) {
            escape = false;
            continue;
          }
          if (c === "\\") {
            escape = true;
            continue;
          }
          if (c === '"') {
            inString = !inString;
            continue;
          }
          if (inString) continue;
          if (c === "{") depth++;
          if (c === "}") {
            depth--;
            if (depth === 0) {
              endIdx = i;
              break;
            }
          }
        }

        if (endIdx === -1) {
          // まだ完全なJSONではない
          break;
        }

        const jsonStr = responseBuffer.slice(startIdx, endIdx + 1);
        responseBuffer = responseBuffer.slice(endIdx + 1);

        try {
          const parsed = JSON.parse(jsonStr);
          // readyメッセージ（id: 0）は無視
          if (parsed.id === 0) continue;

          // 有効なレスポンスを処理
          if (currentResolve && parsed.id !== undefined) {
            currentResolve(JSON.stringify(parsed));
            currentResolve = null;
            currentReject = null;
          }
        } catch {
          // パースエラーは無視
        }
      }
    });

    leanProcess.stderr?.on("data", (data: Buffer) => {
      const text = data.toString();
      console.error("Lean REPL stderr:", text);

      // 初期化完了メッセージを待つ
      if (text.includes("ready") || text.includes("Ready")) {
        resolve();
      }
    });

    leanProcess.on("error", (err) => {
      console.error("Failed to start Lean REPL:", err);
      reject(err);
    });

    leanProcess.on("close", (code) => {
      console.log("Lean REPL exited with code:", code);
      leanProcess = null;
      if (currentReject) {
        currentReject(new Error("Lean REPL process terminated"));
        currentResolve = null;
        currentReject = null;
      }
    });

    // タイムアウト後に解決（REPLが準備完了メッセージを出さない場合）
    setTimeout(() => resolve(), 2000);
  });
}

async function sendToLeanRepl(request: object): Promise<object> {
  if (!leanProcess || leanProcess.killed) {
    await startLeanRepl();
  }

  // 前のレスポンスが残っている場合はクリア
  responseBuffer = "";

  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      currentResolve = null;
      currentReject = null;
      responseBuffer = "";
      reject(new Error("Lean REPL timeout"));
    }, 30000);

    currentResolve = (response: string) => {
      clearTimeout(timeout);
      try {
        resolve(JSON.parse(response));
      } catch (err) {
        reject(new Error(`Invalid JSON response: ${response}`));
      }
    };

    currentReject = (err: Error) => {
      clearTimeout(timeout);
      reject(err);
    };

    const requestStr = JSON.stringify(request) + "\n";
    leanProcess?.stdin?.write(requestStr);
  });
}

// JSON-RPC エンドポイント
app.post("/rpc", async (req, res) => {
  try {
    // デバッグ: リクエストをログ出力
    if (req.body.method === "getWeeklyRecommendations") {
      console.log("=== Weekly Recommendations Request ===");
      console.log("startDay:", req.body.params?.startDay);
      console.log("states:", JSON.stringify(req.body.params?.states, null, 2));
    }
    const response = await sendToLeanRepl(req.body);
    res.json(response);
  } catch (err) {
    console.error("RPC error:", err);
    res.status(500).json({
      jsonrpc: "2.0",
      error: {
        code: -32603,
        message: err instanceof Error ? err.message : "Internal error",
      },
      id: req.body.id || null,
    });
  }
});

// ヘルスチェック
app.get("/health", (req, res) => {
  res.json({
    status: "ok",
    leanRepl: leanProcess && !leanProcess.killed ? "running" : "stopped",
  });
});

// Ping エンドポイント（Lean REPLテスト用）
app.get("/ping", async (req, res) => {
  try {
    const response = await sendToLeanRepl({
      jsonrpc: "2.0",
      method: "ping",
      params: {},
      id: Date.now(),
    });
    res.json(response);
  } catch (err) {
    res.status(500).json({
      error: err instanceof Error ? err.message : "Unknown error",
    });
  }
});

// サーバー起動
async function main() {
  try {
    await startLeanRepl();
    console.log("Lean REPL started successfully");
  } catch (err) {
    console.warn("Could not start Lean REPL immediately:", err);
    console.log("Will attempt to start on first request");
  }

  app.listen(PORT, () => {
    console.log(`API Server running on http://localhost:${PORT}`);
    console.log(`- POST /rpc - JSON-RPC endpoint`);
    console.log(`- GET /health - Health check`);
    console.log(`- GET /ping - Test Lean REPL connection`);
  });
}

// グレースフルシャットダウン
process.on("SIGINT", () => {
  console.log("\nShutting down...");
  if (leanProcess) {
    leanProcess.kill();
  }
  process.exit(0);
});

process.on("SIGTERM", () => {
  if (leanProcess) {
    leanProcess.kill();
  }
  process.exit(0);
});

main();
