import { useState, useCallback } from "react";
import type { SchoolWithState, GetWeeklyRecommendationsResult } from "@/types";
import { getWeeklyRecommendations } from "@/api/client";

export interface UseRecommendationReturn {
  result: GetWeeklyRecommendationsResult | null;
  isLoading: boolean;
  error: string | null;
  fetchRecommendation: (schools: SchoolWithState[], startDate: Date) => Promise<void>;
  clearResult: () => void;
}

export function useRecommendation(): UseRecommendationReturn {
  const [result, setResult] = useState<GetWeeklyRecommendationsResult | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchRecommendation = useCallback(
    async (schools: SchoolWithState[], startDate: Date) => {
      if (schools.length === 0) {
        setError("学校を追加してください");
        return;
      }

      setIsLoading(true);
      setError(null);

      try {
        const data = await getWeeklyRecommendations(schools, startDate, 7);
        setResult(data);
      } catch (err) {
        const message =
          err instanceof Error ? err.message : "エラーが発生しました";
        setError(message);
        setResult(null);
      } finally {
        setIsLoading(false);
      }
    },
    []
  );

  const clearResult = useCallback(() => {
    setResult(null);
    setError(null);
  }, []);

  return {
    result,
    isLoading,
    error,
    fetchRecommendation,
    clearResult,
  };
}
