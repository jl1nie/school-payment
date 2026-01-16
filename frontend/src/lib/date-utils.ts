/**
 * 日付変換ユーティリティ
 *
 * Leanバックエンドは日付をDay番号で扱う（2月1日 = Day 1）
 * フロントエンドはDate型で扱い、API呼び出し時に変換する
 */

/**
 * 基準日を取得（2月1日）
 * 学年度を考慮: 1-3月は同年度、4-12月は翌年の2月1日
 */
export function getBaseDate(year?: number): Date {
  const targetYear = year ?? new Date().getFullYear();
  return new Date(targetYear, 1, 1); // 2月1日 (month is 0-indexed)
}

/**
 * Date を Day番号に変換（2月1日 = Day 1）
 */
export function dateToDay(date: Date, baseYear?: number): number {
  const baseDate = getBaseDate(baseYear);
  const diffTime = date.getTime() - baseDate.getTime();
  const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));
  return diffDays + 1;
}

/**
 * Day番号を Date に変換
 */
export function dayToDate(day: number, baseYear?: number): Date {
  const baseDate = getBaseDate(baseYear);
  const result = new Date(baseDate);
  result.setDate(result.getDate() + day - 1);
  return result;
}

/**
 * 日付を日本語形式でフォーマット
 */
export function formatDate(date: Date): string {
  return date.toLocaleDateString("ja-JP", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });
}

/**
 * 日付を短い形式でフォーマット（M/D）
 */
export function formatDateShort(date: Date): string {
  return `${date.getMonth() + 1}/${date.getDate()}`;
}

/**
 * 金額を日本円形式でフォーマット
 */
export function formatYen(amount: number): string {
  return new Intl.NumberFormat("ja-JP", {
    style: "currency",
    currency: "JPY",
  }).format(amount);
}

/**
 * 2つの日付の差分（日数）を計算
 */
export function daysBetween(from: Date, to: Date): number {
  const diffTime = to.getTime() - from.getTime();
  return Math.floor(diffTime / (1000 * 60 * 60 * 24));
}

/**
 * 期限までの残り日数を計算
 */
export function daysUntil(deadline: Date, today: Date = new Date()): number {
  return daysBetween(today, deadline);
}
