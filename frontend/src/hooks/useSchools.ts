import { useState, useCallback, useEffect, useRef } from "react";
import type { SchoolWithState, PassStatus } from "@/types";
import { saveSchools, loadSchools } from "@/api/storage";

export interface UseSchoolsReturn {
  schools: SchoolWithState[];
  addSchool: (school: SchoolWithState) => void;
  updateSchool: (school: SchoolWithState) => void;
  removeSchool: (id: number) => void;
  updatePassStatus: (id: number, status: PassStatus) => void;
  updatePaymentStatus: (
    id: number,
    updates: { enrollmentFeePaid?: boolean; tuitionPaid?: boolean }
  ) => void;
  reorderSchools: (orderedIds: number[]) => void;
  clearSchools: () => void;
  getNextId: () => number;
  getNextPriority: () => number;
  exportData: () => string;
  parseImportData: (json: string) => SchoolWithState[] | null;
  setValidatedSchools: (schools: SchoolWithState[]) => void;
  loadSampleData: (sampleSchools: SchoolWithState[]) => void;
  isLoading: boolean;
}

export function useSchools(
  initialSchools?: SchoolWithState[]
): UseSchoolsReturn {
  const [schools, setSchools] = useState<SchoolWithState[]>(
    initialSchools ?? []
  );
  const [isLoading, setIsLoading] = useState(true);
  const isInitialized = useRef(false);

  // 初回マウント時にストレージからデータを読み込み
  useEffect(() => {
    if (isInitialized.current) return;
    isInitialized.current = true;

    // 初期データが渡されている場合はそれを使用
    if (initialSchools && initialSchools.length > 0) {
      setIsLoading(false);
      return;
    }

    // ストレージからデータを読み込み
    loadSchools()
      .then((loaded) => {
        if (loaded && loaded.length > 0) {
          setSchools(loaded);
        }
      })
      .catch((e) => {
        console.error("Failed to load from storage:", e);
      })
      .finally(() => {
        setIsLoading(false);
      });
  }, [initialSchools]);

  // schoolsが変更されたらストレージに保存
  useEffect(() => {
    // 初期化中は保存しない
    if (isLoading) return;

    saveSchools(schools).catch((e) => {
      console.error("Failed to save to storage:", e);
    });
  }, [schools, isLoading]);

  const addSchool = useCallback((school: SchoolWithState) => {
    setSchools((prev) => {
      const updated = [...prev, school];
      return updated.sort((a, b) => a.priority - b.priority);
    });
  }, []);

  const updateSchool = useCallback((school: SchoolWithState) => {
    setSchools((prev) => {
      const updated = prev.map((s) => (s.id === school.id ? school : s));
      return updated.sort((a, b) => a.priority - b.priority);
    });
  }, []);

  const removeSchool = useCallback((id: number) => {
    setSchools((prev) => {
      const filtered = prev.filter((s) => s.id !== id);
      // 優先順位を再割り当て
      return filtered.map((s, i) => ({ ...s, priority: i + 1 }));
    });
  }, []);

  const updatePassStatus = useCallback((id: number, status: PassStatus) => {
    setSchools((prev) =>
      prev.map((s) => (s.id === id ? { ...s, passStatus: status } : s))
    );
  }, []);

  const updatePaymentStatus = useCallback(
    (
      id: number,
      updates: { enrollmentFeePaid?: boolean; tuitionPaid?: boolean }
    ) => {
      setSchools((prev) =>
        prev.map((s) => {
          if (s.id !== id) return s;

          const enrollmentFeePaid =
            updates.enrollmentFeePaid ?? s.enrollmentFeePaid;
          let tuitionPaid = updates.tuitionPaid ?? s.tuitionPaid;

          // ビジネスルール: 入学金未払いでは授業料は払えない
          if (tuitionPaid && !enrollmentFeePaid) {
            tuitionPaid = false;
          }

          return { ...s, enrollmentFeePaid, tuitionPaid };
        })
      );
    },
    []
  );

  const reorderSchools = useCallback((orderedIds: number[]) => {
    setSchools((prev) => {
      const schoolMap = new Map(prev.map((s) => [s.id, s]));
      return orderedIds
        .map((id, index) => {
          const school = schoolMap.get(id);
          return school ? { ...school, priority: index + 1 } : null;
        })
        .filter((s): s is SchoolWithState => s !== null);
    });
  }, []);

  const clearSchools = useCallback(() => {
    setSchools([]);
  }, []);

  const getNextId = useCallback(() => {
    return schools.reduce((max, s) => Math.max(max, s.id), 0) + 1;
  }, [schools]);

  const getNextPriority = useCallback(() => {
    return schools.length + 1;
  }, [schools]);

  /**
   * データをJSON文字列としてエクスポート
   */
  const exportData = useCallback(() => {
    const exportObj = {
      version: 1,
      exportedAt: new Date().toISOString(),
      schools,
    };
    return JSON.stringify(exportObj, null, 2);
  }, [schools]);

  /**
   * JSON文字列からデータをパース（バリデーションなし）
   * Leanでのバリデーション後にsetSchoolsを呼ぶこと
   * @returns パースされたデータ、またはnull
   */
  const parseImportData = useCallback((json: string): SchoolWithState[] | null => {
    try {
      const data = JSON.parse(json);

      // バージョン1のフォーマット
      if (data.version === 1 && Array.isArray(data.schools)) {
        return data.schools;
      }

      // 旧フォーマット（配列のみ）
      if (Array.isArray(data)) {
        return data;
      }

      console.error("Invalid data format");
      return null;
    } catch (e) {
      console.error("Failed to parse import data:", e);
      return null;
    }
  }, []);

  /**
   * バリデーション済みデータをセット
   */
  const setValidatedSchools = useCallback((schools: SchoolWithState[]) => {
    setSchools(schools);
  }, []);

  /**
   * サンプルデータを読み込み
   */
  const loadSampleData = useCallback((sampleSchools: SchoolWithState[]) => {
    setSchools(sampleSchools);
  }, []);

  return {
    schools,
    addSchool,
    updateSchool,
    removeSchool,
    updatePassStatus,
    updatePaymentStatus,
    reorderSchools,
    clearSchools,
    getNextId,
    getNextPriority,
    exportData,
    parseImportData,
    setValidatedSchools,
    loadSampleData,
    isLoading,
  };
}
