import { useState, useRef } from "react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Calendar } from "@/components/Calendar";
import { SchoolList } from "@/components/SchoolList";
import { SchoolForm } from "@/components/SchoolForm";
import { WeeklyRecommendationCard } from "@/components/WeeklyRecommendationCard";
import { useSchools } from "@/hooks/useSchools";
import { useRecommendation } from "@/hooks/useRecommendation";
import { sampleSchools } from "@/data/sampleData";
import type { SchoolWithState } from "@/types";

function App() {
  const [today, setToday] = useState<Date>(new Date());
  const [calendarMonth, setCalendarMonth] = useState<Date>(new Date());
  const [showForm, setShowForm] = useState(false);
  const [editingSchool, setEditingSchool] = useState<SchoolWithState | null>(
    null
  );
  const fileInputRef = useRef<HTMLInputElement>(null);

  const {
    schools,
    addSchool,
    updateSchool,
    removeSchool,
    updatePassStatus,
    updatePaymentStatus,
    getNextId,
    getNextPriority,
    exportData,
    importData,
    loadSampleData,
  } = useSchools();

  const {
    result: recommendation,
    isLoading,
    error,
    fetchRecommendation,
    clearResult,
  } = useRecommendation();

  const handleAddSchool = () => {
    setEditingSchool(null);
    setShowForm(true);
  };

  const handleEditSchool = (school: SchoolWithState) => {
    setEditingSchool(school);
    setShowForm(true);
  };

  const handleSaveSchool = (school: SchoolWithState) => {
    if (editingSchool) {
      updateSchool(school);
    } else {
      addSchool(school);
    }
    setShowForm(false);
    setEditingSchool(null);
    clearResult();
  };

  const handleCancelForm = () => {
    setShowForm(false);
    setEditingSchool(null);
  };

  const handleDeleteSchool = (id: number) => {
    if (confirm("この学校を削除しますか？")) {
      removeSchool(id);
      clearResult();
    }
  };

  const handleGetRecommendation = async () => {
    await fetchRecommendation(schools, today);
  };

  // データエクスポート
  const handleExport = () => {
    const json = exportData();
    const blob = new Blob([json], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `school-payment-backup-${new Date().toISOString().slice(0, 10)}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  // データインポート
  const handleImportClick = () => {
    fileInputRef.current?.click();
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      const json = event.target?.result as string;
      if (importData(json)) {
        alert("データをインポートしました");
        clearResult();
      } else {
        alert("インポートに失敗しました。ファイル形式を確認してください。");
      }
    };
    reader.readAsText(file);

    // 同じファイルを再選択できるようにリセット
    e.target.value = "";
  };

  // サンプルデータを読み込み
  const handleLoadSample = () => {
    if (
      schools.length === 0 ||
      confirm(
        "現在のデータを上書きしてサンプルデータを読み込みますか？\n（東大・早稲田・慶應・明治・東京理科大の2026年度入試データ）"
      )
    ) {
      loadSampleData(sampleSchools);
      clearResult();
    }
  };

  return (
    <div className="min-h-screen bg-gray-100">
      {/* ヘッダー */}
      <header className="bg-white shadow">
        <div className="max-w-6xl mx-auto px-4 py-6">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-gray-900">
                志望校支払いアドバイザー
              </h1>
              <p className="text-sm text-gray-600 mt-1">
                〜Lean4定理証明による支払い戦略〜
              </p>
            </div>
          </div>
        </div>
      </header>

      <main className="max-w-6xl mx-auto px-4 py-6 space-y-6">
        {/* カレンダー */}
        <Calendar
          schools={schools}
          today={today}
          selectedMonth={calendarMonth}
          onMonthChange={setCalendarMonth}
          onDateSelect={setToday}
        />

        {/* アクションボタン */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <Button
              size="lg"
              onClick={handleGetRecommendation}
              disabled={isLoading || schools.length === 0}
              className="px-8"
            >
              {isLoading ? "取得中..." : "🔍 1週間の推奨アクションを取得"}
            </Button>
          </div>
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={handleExport}
              disabled={schools.length === 0}
            >
              📤 エクスポート
            </Button>
            <Button variant="outline" size="sm" onClick={handleImportClick}>
              📥 インポート
            </Button>
            <Button variant="outline" size="sm" onClick={handleLoadSample}>
              📝 サンプル
            </Button>
            <input
              ref={fileInputRef}
              type="file"
              accept=".json"
              onChange={handleFileChange}
              className="hidden"
            />
          </div>
        </div>

        {/* エラー表示 */}
        {error && (
          <Card className="border-red-300 bg-red-50">
            <CardContent className="pt-6">
              <p className="text-red-600">{error}</p>
            </CardContent>
          </Card>
        )}

        {/* 推奨アクション表示 */}
        {recommendation && (
          <div>
            <h2 className="text-lg font-semibold mb-4">📋 1週間の推奨アクション</h2>
            <WeeklyRecommendationCard
              result={recommendation}
              schools={schools}
            />
          </div>
        )}

        {/* 学校フォーム（モーダル的に表示） */}
        {showForm && (
          <SchoolForm
            school={editingSchool}
            nextId={getNextId()}
            nextPriority={getNextPriority()}
            onSave={handleSaveSchool}
            onCancel={handleCancelForm}
          />
        )}

        {/* 志望校一覧 */}
        <div>
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold">🏫 志望校一覧</h2>
            {!showForm && (
              <Button variant="outline" onClick={handleAddSchool}>
                ＋ 学校を追加
              </Button>
            )}
          </div>
          <SchoolList
            schools={schools}
            onUpdatePassStatus={updatePassStatus}
            onUpdatePaymentStatus={updatePaymentStatus}
            onEdit={handleEditSchool}
            onDelete={handleDeleteSchool}
          />
        </div>
      </main>

      {/* フッター */}
      <footer className="bg-white border-t mt-12">
        <div className="max-w-6xl mx-auto px-4 py-4 text-center text-sm text-gray-500">
          <p>志望校支払いアドバイザー - Lean4形式検証によるビジネスロジック</p>
        </div>
      </footer>
    </div>
  );
}

export default App;
