/**
 * 日付変換ユーティリティ
 *
 * 日付はYYYYMMDD形式の整数で管理（例: 20260225 = 2026年2月25日）
 * 整数の大小比較がそのまま日付の前後関係となる
 */

/**
 * Date を YYYYMMDD形式の整数に変換
 */
export function dateToDay(date: Date): number {
  const year = date.getFullYear();
  const month = date.getMonth() + 1; // 0-indexed → 1-indexed
  const day = date.getDate();
  return year * 10000 + month * 100 + day;
}

/**
 * YYYYMMDD形式の整数を Date に変換
 */
export function dayToDate(day: number): Date {
  const year = Math.floor(day / 10000);
  const month = Math.floor((day % 10000) / 100) - 1; // 1-indexed → 0-indexed
  const d = day % 100;
  return new Date(year, month, d);
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
 * YYYYMMDD形式の整数を短い形式でフォーマット（M/D）
 */
export function formatDayShort(day: number): string {
  const month = Math.floor((day % 10000) / 100);
  const d = day % 100;
  return `${month}/${d}`;
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

/**
 * YYYYMMDD形式の2つの日付の差分（日数）を計算
 */
export function daysBetweenDays(fromDay: number, toDay: number): number {
  const from = dayToDate(fromDay);
  const to = dayToDate(toDay);
  return daysBetween(from, to);
}
