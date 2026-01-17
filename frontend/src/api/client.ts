/**
 * API クライアント - Lean REPL との JSON-RPC 通信
 *
 * Tauri デスクトップ版と Web 版の両方をサポート。
 * 環境に応じて invoke または HTTP fetch を使用。
 */

import { z } from "zod";
import type {
  SchoolWithState,
  SchoolInput,
  StateInput,
  GetRecommendationResult,
  GetWeeklyRecommendationsResult,
  JsonRpcResponse,
} from "@/types";
import { dateToDay } from "@/lib/date-utils";

const API_BASE_URL = import.meta.env.VITE_API_URL || "http://localhost:3001";

// Tauri 環境判定
declare global {
  interface Window {
    __TAURI__?: unknown;
    __TAURI_INTERNALS__?: unknown;
  }
}

/**
 * Tauri 環境かどうかを判定
 */
export function isTauri(): boolean {
  return (
    typeof window !== "undefined" &&
    ("__TAURI__" in window || "__TAURI_INTERNALS__" in window)
  );
}

// Zod スキーマ（ランタイムバリデーション）
const PaymentActionSchema = z.object({
  type: z.enum(["payEnrollmentFee", "payTuition", "doNothing"]),
  schoolId: z.number().optional(),
});

const RecommendationSchema = z.object({
  action: PaymentActionSchema,
  reason: z.string(),
  urgency: z.number(),
});

const GetRecommendationResultSchema = z.object({
  action: PaymentActionSchema,
  reason: z.string(),
  urgency: z.number(),
  allRecommendations: z.array(RecommendationSchema),
});

let requestId = 0;

/**
 * JSON-RPC リクエスト型
 */
interface JsonRpcRequest {
  jsonrpc: string;
  method: string;
  params: unknown;
  id: number;
}

/**
 * JSON-RPC リクエストを送信（環境に応じて invoke または fetch を使用）
 */
async function sendRpcRequest<T>(request: JsonRpcRequest): Promise<T> {
  if (isTauri()) {
    // Tauri デスクトップアプリ
    const { invoke } = await import("@tauri-apps/api/core");
    const response = await invoke<JsonRpcResponse<T>>("send_rpc", { request });

    if (response.error) {
      throw new Error(response.error.message);
    }

    return response.result as T;
  } else {
    // Web 版（HTTP fetch）
    const response = await fetch(`${API_BASE_URL}/rpc`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(request),
    });

    if (!response.ok) {
      throw new Error(`HTTP error: ${response.status}`);
    }

    const json: JsonRpcResponse<T> = await response.json();

    if (json.error) {
      throw new Error(json.error.message);
    }

    return json.result as T;
  }
}

/**
 * SchoolWithState 配列を API 形式に変換
 * 日付はYYYYMMDD形式の整数
 */
function toApiFormat(
  schools: SchoolWithState[],
  today: Date
): {
  today: number;
  schools: SchoolInput[];
  states: StateInput[];
} {
  return {
    today: dateToDay(today),
    schools: schools.map((s) => ({
      id: s.id,
      name: s.name,
      priority: s.priority,
      examDate: s.examDate,
      resultDate: s.resultDate,
      enrollmentFeeDeadline: s.enrollmentFeeDeadline,
      tuitionDeadline: s.tuitionDeadline,
      enrollmentFee: s.enrollmentFee,
      tuition: s.tuition,
    })),
    states: schools.map((s) => ({
      schoolId: s.id,
      passStatus: s.passStatus,
      enrollmentFeePaid: s.enrollmentFeePaid,
      tuitionPaid: s.tuitionPaid,
    })),
  };
}

/**
 * 推奨アクションを取得
 */
export async function getRecommendation(
  schools: SchoolWithState[],
  today: Date
): Promise<GetRecommendationResult> {
  const params = toApiFormat(schools, today);

  const result = await sendRpcRequest<unknown>({
    jsonrpc: "2.0",
    method: "getRecommendation",
    params,
    id: ++requestId,
  });

  // ランタイムバリデーション
  return GetRecommendationResultSchema.parse(result);
}

// Zodスキーマ: getWeeklyRecommendations用
const DailyRecommendationSchema = z.object({
  day: z.number(),
  result: GetRecommendationResultSchema,
});

const UpcomingAnnouncementSchema = z.object({
  schoolId: z.number(),
  schoolName: z.string(),
  resultDay: z.number(),
});

const GetWeeklyRecommendationsResultSchema = z.object({
  startDay: z.number(),
  recommendations: z.array(DailyRecommendationSchema),
  upcomingAnnouncements: z.array(UpcomingAnnouncementSchema),
  note: z.string().nullable(),
});

/**
 * 1週間分の推奨アクションを取得（Lean APIを1回呼び出し）
 */
export async function getWeeklyRecommendations(
  schools: SchoolWithState[],
  startDate: Date,
  days: number = 7
): Promise<GetWeeklyRecommendationsResult> {
  const startDay = dateToDay(startDate);

  const result = await sendRpcRequest<unknown>({
    jsonrpc: "2.0",
    method: "getWeeklyRecommendations",
    params: {
      startDay,
      days,
      schools: schools.map((s) => ({
        id: s.id,
        name: s.name,
        priority: s.priority,
        examDate: s.examDate,
        resultDate: s.resultDate,
        enrollmentFeeDeadline: s.enrollmentFeeDeadline,
        tuitionDeadline: s.tuitionDeadline,
        enrollmentFee: s.enrollmentFee,
        tuition: s.tuition,
      })),
      states: schools.map((s) => ({
        schoolId: s.id,
        passStatus: s.passStatus,
        enrollmentFeePaid: s.enrollmentFeePaid,
        tuitionPaid: s.tuitionPaid,
      })),
    },
    id: ++requestId,
  });

  // ランタイムバリデーション
  return GetWeeklyRecommendationsResultSchema.parse(result);
}

/**
 * サーバー接続確認
 */
export async function ping(): Promise<boolean> {
  try {
    const result = await sendRpcRequest<string>({
      jsonrpc: "2.0",
      method: "ping",
      params: {},
      id: ++requestId,
    });
    return result === "pong";
  } catch {
    return false;
  }
}

/**
 * ヘルスチェック（Tauri 専用）
 */
export async function healthCheck(): Promise<{
  status: string;
  lean_repl: string;
}> {
  if (isTauri()) {
    const { invoke } = await import("@tauri-apps/api/core");
    return invoke("health_check");
  } else {
    const response = await fetch(`${API_BASE_URL}/health`);
    return response.json();
  }
}

/**
 * REPL 再起動（Tauri 専用）
 */
export async function restartRepl(): Promise<void> {
  if (isTauri()) {
    const { invoke } = await import("@tauri-apps/api/core");
    await invoke("restart_repl");
  } else {
    throw new Error("restartRepl is only available in Tauri desktop app");
  }
}
