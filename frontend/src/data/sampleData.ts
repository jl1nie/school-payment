/**
 * サンプルデータ: 2025年度 理系情報系 受験シナリオ
 *
 * 典型的な国立+私立の併願パターン
 * - 第1志望: 東京大学 理科一類（国立）
 * - 第2志望: 早稲田大学 基幹理工学部（私立）
 * - 第3志望: 慶應義塾大学 理工学部（私立）
 * - 第4志望: 東京理科大学 工学部 情報工学科（私立・滑り止め）
 *
 * 日付基準: 2025年2月1日 = Day 1
 *
 * Sources:
 * - 東京大学: https://www.u-tokyo.ac.jp/ja/admissions/undergraduate/e01_02_01.html
 * - 早稲田大学: https://www.shindaigakusei.club/entry/waseda_gokaku
 * - 慶應義塾大学: https://www.shindaigakusei.club/entry/keio-riko-kaitosokuho
 * - 東京理科大学: https://passnavi.obunsha.co.jp/univ/2880/schedule/
 */

import type { SchoolWithState } from "@/types";

/**
 * 日付をDay番号に変換（2月1日 = Day 1）
 */
function toDay(month: number, day: number): number {
  // 2月1日 = Day 1
  if (month === 2) return day;
  if (month === 3) return 28 + day; // 2月は28日
  if (month === 4) return 28 + 31 + day;
  return day;
}

export const sampleSchools: SchoolWithState[] = [
  {
    // 第1志望: 東京大学 理科一類
    id: 1,
    name: "東京大学 理科一類",
    priority: 1,
    examDate: toDay(2, 25),          // 2/25-26 二次試験
    resultDate: toDay(3, 10),         // 3/10 合格発表
    enrollmentFeeDeadline: toDay(3, 15), // 3/15頃 入学手続き締切（推定）
    tuitionDeadline: toDay(3, 31),    // 3/31 授業料締切（推定）
    enrollmentFee: 282000,            // 入学金 28万2千円
    tuition: 535800,                  // 授業料（年額）53万5800円
    passStatus: "notYetAnnounced",
    enrollmentFeePaid: false,
    tuitionPaid: false,
  },
  {
    // 第2志望: 早稲田大学 基幹理工学部
    id: 2,
    name: "早稲田大学 基幹理工学部",
    priority: 2,
    examDate: toDay(2, 16),           // 2/16 一般入試
    resultDate: toDay(2, 27),         // 2/27 合格発表
    enrollmentFeeDeadline: toDay(3, 4), // 3/4 第1次振込締切（入学金）
    tuitionDeadline: toDay(3, 24),    // 3/24 第2次振込締切（授業料）
    enrollmentFee: 200000,            // 入学金 20万円
    tuition: 1447000,                 // 授業料等（春学期分相当）
    passStatus: "notYetAnnounced",
    enrollmentFeePaid: false,
    tuitionPaid: false,
  },
  {
    // 第3志望: 慶應義塾大学 理工学部
    id: 3,
    name: "慶應義塾大学 理工学部",
    priority: 3,
    examDate: toDay(2, 12),           // 2/12 一般入試
    resultDate: toDay(2, 24),         // 2/24 合格発表
    enrollmentFeeDeadline: toDay(3, 3), // 3/3 入学金支払期限
    tuitionDeadline: toDay(3, 24),    // 3/24 延納者授業料支払期限
    enrollmentFee: 200000,            // 入学金 20万円
    tuition: 1480000,                 // 授業料等
    passStatus: "notYetAnnounced",
    enrollmentFeePaid: false,
    tuitionPaid: false,
  },
  {
    // 第4志望: 東京理科大学 工学部 情報工学科（B方式）
    id: 4,
    name: "東京理科大学 工学部",
    priority: 4,
    examDate: toDay(2, 8),            // 2/8 B方式試験
    resultDate: toDay(2, 23),         // 2/23 合格発表
    enrollmentFeeDeadline: toDay(2, 28), // 2/28 入学手続締切
    tuitionDeadline: toDay(3, 11),    // 3/11 二次入学手続き締切
    enrollmentFee: 300000,            // 入学金 30万円
    tuition: 1240000,                 // 授業料等
    passStatus: "notYetAnnounced",
    enrollmentFeePaid: false,
    tuitionPaid: false,
  },
];

/**
 * エクスポート形式のサンプルデータ
 */
export const sampleDataJson = {
  version: 1,
  exportedAt: "2025-02-01T00:00:00.000Z",
  description: "2025年度 理系情報系 受験サンプルデータ（東大・早稲田・慶應・理科大）",
  schools: sampleSchools,
};
