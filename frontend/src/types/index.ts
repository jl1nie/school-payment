/**
 * 型定義 - Leanバックエンドの型と対応
 */

/** 合否状態（Lean: PassStatus） */
export type PassStatus = "notYetAnnounced" | "passed" | "failed" | "cancelled";

/** 合否状態の日本語ラベル */
export const passStatusLabels: Record<PassStatus, string> = {
  notYetAnnounced: "未発表",
  passed: "合格",
  failed: "不合格",
  cancelled: "取消",
};

/**
 * 学校の状態を含む情報（フロントエンド内部用）
 * 日付はDay番号として保持（Leanと同じ形式）
 */
export interface SchoolWithState {
  id: number;
  name: string;
  priority: number;
  examDate: number; // Day番号
  resultDate: number;
  enrollmentFeeDeadline: number;
  tuitionDeadline: number;
  enrollmentFee: number;
  tuition: number;
  passStatus: PassStatus;
  enrollmentFeePaid: boolean;
  tuitionPaid: boolean;
}

/** API用学校情報（Lean: SchoolInput） */
export interface SchoolInput {
  id: number;
  name: string;
  priority: number;
  examDate: number; // Day番号
  resultDate: number;
  enrollmentFeeDeadline: number;
  tuitionDeadline: number;
  enrollmentFee: number;
  tuition: number;
}

/** API用状態情報（Lean: StateInput） */
export interface StateInput {
  schoolId: number;
  passStatus: string;
  enrollmentFeePaid: boolean;
  tuitionPaid: boolean;
}

/** 支払いアクション（Lean: PaymentAction） */
export interface PaymentAction {
  type: "payEnrollmentFee" | "payTuition" | "doNothing";
  schoolId?: number;
}

/** 推奨アクション（Lean: Recommendation） */
export interface Recommendation {
  action: PaymentAction;
  reason: string;
  urgency: number; // 0 = 本日期限
}

/** getRecommendation レスポンス */
export interface GetRecommendationResult {
  action: PaymentAction;
  reason: string;
  urgency: number;
  allRecommendations: Recommendation[];
}

/** 1日分の推奨アクション（Lean APIレスポンス） */
export interface DailyRecommendation {
  day: number;
  result: GetRecommendationResult;
}

/** 発表予定の学校情報（Lean APIレスポンス） */
export interface UpcomingAnnouncement {
  schoolId: number;
  schoolName: string;
  resultDay: number;
}

/** getWeeklyRecommendations レスポンス（Lean APIレスポンス） */
export interface GetWeeklyRecommendationsResult {
  startDay: number;
  recommendations: DailyRecommendation[];
  upcomingAnnouncements: UpcomingAnnouncement[];
  note: string | null;
}

/** JSON-RPC リクエスト */
export interface JsonRpcRequest {
  jsonrpc: "2.0";
  method: string;
  params: unknown;
  id: number;
}

/** JSON-RPC レスポンス */
export interface JsonRpcResponse<T> {
  jsonrpc: "2.0";
  result?: T;
  error?: {
    code: number;
    message: string;
  };
  id: number;
}
