/**
 * サンプルデータ: 2026年度 理系情報系 受験シナリオ
 *
 * 典型的な国立+私立の併願パターン
 * - 第1志望: 東京大学 理科一類（国立）
 * - 第2志望: 早稲田大学 基幹理工学部（私立）
 * - 第3志望: 慶應義塾大学 理工学部（私立）
 * - 第4志望: 東京理科大学 工学部（私立）
 * - 第5志望: 明治大学 理工学部（私立・滑り止め）
 *
 * 日付形式: YYYYMMDD形式の整数（例: 20260225 = 2026年2月25日）
 *
 * Sources:
 * - 東京大学: https://www.u-tokyo.ac.jp/ja/admissions/undergraduate/e01_02_01.html
 * - 早稲田大学: https://passnavi.obunsha.co.jp/univ/3190/schedule/
 * - 慶應義塾大学: https://passnavi.obunsha.co.jp/univ/2370/schedule/
 * - 明治大学: https://passnavi.obunsha.co.jp/univ/3120/schedule/
 * - 東京理科大学: https://passnavi.obunsha.co.jp/univ/2880/schedule/
 */

import type { SchoolWithState } from "@/types";

export const sampleSchools: SchoolWithState[] = [
  {
    // 第1志望: 東京大学 理科一類
    id: 1,
    name: "東京大学 理科一類",
    priority: 1,
    examDate: 20260225,              // 2/25-26 二次試験
    resultDate: 20260310,            // 3/10 合格発表
    enrollmentFeeDeadline: 20260317, // 3/17頃 入学手続き締切（推定）
    tuitionDeadline: 20260331,       // 3/31 授業料締切（推定）
    enrollmentFee: 282000,           // 入学金 28万2千円
    tuition: 535800,                 // 授業料（年額）53万5800円
    passStatus: "notYetAnnounced",
    enrollmentFeePaid: false,
    tuitionPaid: false,
  },
  {
    // 第2志望: 早稲田大学 基幹理工学部
    id: 2,
    name: "早稲田大学 基幹理工学部",
    priority: 2,
    examDate: 20260216,              // 2/16 一般入試
    resultDate: 20260227,            // 2/27 合格発表
    enrollmentFeeDeadline: 20260306, // 3/6 第1次振込締切（入学金）
    tuitionDeadline: 20260324,       // 3/24 第2次振込締切（授業料）
    enrollmentFee: 200000,           // 入学金 20万円
    tuition: 1447000,                // 授業料等（春学期分相当）
    passStatus: "notYetAnnounced",
    enrollmentFeePaid: false,
    tuitionPaid: false,
  },
  {
    // 第3志望: 慶應義塾大学 理工学部
    id: 3,
    name: "慶應義塾大学 理工学部",
    priority: 3,
    examDate: 20260212,              // 2/12 一般入試
    resultDate: 20260224,            // 2/24 合格発表
    enrollmentFeeDeadline: 20260303, // 3/3 入学金支払期限
    tuitionDeadline: 20260324,       // 3/24 授業料支払期限
    enrollmentFee: 200000,           // 入学金 20万円
    tuition: 1480000,                // 授業料等
    passStatus: "notYetAnnounced",
    enrollmentFeePaid: false,
    tuitionPaid: false,
  },
  {
    // 第4志望: 東京理科大学 工学部（B方式）
    id: 4,
    name: "東京理科大学 工学部",
    priority: 4,
    examDate: 20260208,              // 2/8 B方式試験
    resultDate: 20260225,            // 2/25 合格発表
    enrollmentFeeDeadline: 20260302, // 3/2 入学手続締切
    tuitionDeadline: 20260311,       // 3/11 二次入学手続き締切
    enrollmentFee: 300000,           // 入学金 30万円
    tuition: 1240000,                // 授業料等
    passStatus: "notYetAnnounced",
    enrollmentFeePaid: false,
    tuitionPaid: false,
  },
  {
    // 第5志望: 明治大学 理工学部
    id: 5,
    name: "明治大学 理工学部",
    priority: 5,
    examDate: 20260207,              // 2/7 学部別入試
    resultDate: 20260214,            // 2/14 合格発表
    enrollmentFeeDeadline: 20260226, // 2/26 入学手続締切
    tuitionDeadline: 20260325,       // 3/25 延納第二次手続締切
    enrollmentFee: 250000,           // 入学金 25万円
    tuition: 1200000,                // 授業料等
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
  exportedAt: "2026-02-01T00:00:00.000Z",
  description: "2026年度 理系情報系 受験サンプルデータ（東大・早稲田・慶應・明治・東京理科大）",
  schools: sampleSchools,
};
