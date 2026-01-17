/**
 * ストレージ API - デスクトップ版でのデータ永続化
 *
 * Tauri デスクトップ版ではローカルファイルに保存。
 * Web 版では localStorage を使用（フォールバック）。
 */

import type { SchoolWithState } from "@/types";
import { isTauri } from "./client";

const STORAGE_KEY = "school-payment-data";

/**
 * 学校データを保存
 */
export async function saveSchools(schools: SchoolWithState[]): Promise<void> {
  if (isTauri()) {
    const { invoke } = await import("@tauri-apps/api/core");
    await invoke("save_data", { data: { schools } });
  } else {
    // Web 版: localStorage にフォールバック
    localStorage.setItem(STORAGE_KEY, JSON.stringify({ schools }));
  }
}

/**
 * 学校データを読み込み
 */
export async function loadSchools(): Promise<SchoolWithState[] | null> {
  if (isTauri()) {
    const { invoke } = await import("@tauri-apps/api/core");
    const data = await invoke<{ schools: SchoolWithState[] } | null>("load_data");
    return data?.schools ?? null;
  } else {
    // Web 版: localStorage からフォールバック
    const stored = localStorage.getItem(STORAGE_KEY);
    if (!stored) return null;
    try {
      const data = JSON.parse(stored);
      return data.schools ?? null;
    } catch {
      return null;
    }
  }
}
