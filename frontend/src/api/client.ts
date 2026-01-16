/**
 * API クライアント - Lean REPL との JSON-RPC 通信
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
 * SchoolWithState 配列を API 形式に変換
 * SchoolWithStateの日付は既にDay番号なので直接使用
 */
function toApiFormat(
  schools: SchoolWithState[],
  today: Date,
  baseYear?: number
): {
  today: number;
  schools: SchoolInput[];
  states: StateInput[];
} {
  return {
    today: dateToDay(today, baseYear),
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
  today: Date,
  baseYear?: number
): Promise<GetRecommendationResult> {
  const params = toApiFormat(schools, today, baseYear);

  const response = await fetch(`${API_BASE_URL}/rpc`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      jsonrpc: "2.0",
      method: "getRecommendation",
      params,
      id: ++requestId,
    }),
  });

  if (!response.ok) {
    throw new Error(`HTTP error: ${response.status}`);
  }

  const json: JsonRpcResponse<unknown> = await response.json();

  if (json.error) {
    throw new Error(json.error.message);
  }

  // ランタイムバリデーション
  return GetRecommendationResultSchema.parse(json.result);
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
  days: number = 7,
  baseYear?: number
): Promise<GetWeeklyRecommendationsResult> {
  const startDay = dateToDay(startDate, baseYear);

  const response = await fetch(`${API_BASE_URL}/rpc`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
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
    }),
  });

  if (!response.ok) {
    throw new Error(`HTTP error: ${response.status}`);
  }

  const json: JsonRpcResponse<unknown> = await response.json();

  if (json.error) {
    throw new Error(json.error.message);
  }

  // ランタイムバリデーション
  return GetWeeklyRecommendationsResultSchema.parse(json.result);
}

/**
 * サーバー接続確認
 */
export async function ping(): Promise<boolean> {
  try {
    const response = await fetch(`${API_BASE_URL}/rpc`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        jsonrpc: "2.0",
        method: "ping",
        params: {},
        id: ++requestId,
      }),
    });
    const json = await response.json();
    return json.result === "pong";
  } catch {
    return false;
  }
}
