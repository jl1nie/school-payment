import { useState, useEffect } from "react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Calendar } from "@/components/Calendar";
import { SchoolList } from "@/components/SchoolList";
import { WeeklyRecommendationCard } from "@/components/WeeklyRecommendationCard";
import { useSchools } from "@/hooks/useSchools";
import { useRecommendation } from "@/hooks/useRecommendation";
import { sampleSchools } from "@/data/sampleData";
import { save, open } from "@tauri-apps/plugin-dialog";
import { writeTextFile, readTextFile } from "@tauri-apps/plugin-fs";
import { getRecommendation } from "@/api/client";
import type { SchoolWithState } from "@/types";

function App() {
  const [today, setToday] = useState<Date>(new Date());
  const [calendarMonth, setCalendarMonth] = useState<Date>(new Date());
  

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
    parseImportData,
    setValidatedSchools,
    loadSampleData,
  } = useSchools();

  const {
    result: recommendation,
    isLoading,
    error,
    fetchRecommendation,
  } = useRecommendation();

  // 日付または学校データが変更されたら自動的に推奨アクションを取得
  useEffect(() => {
    if (schools.length > 0) {
      fetchRecommendation(schools, today);
    }
  }, [today, schools]);

  // 注意: stateUpdates（期限切れによるキャンセルなど）は自動適用しない
  // WeeklyRecommendationCardで警告として表示されるので、ユーザーが手動で対応する
  // 自動適用すると、日付を変更してシミュレーションする際に永続的に状態が変わってしまう

  const handleEditSchool = (school: SchoolWithState) => {
    // インライン編集からの直接更新
    updateSchool(school);
  };

  const handleAddSchool = (school: SchoolWithState) => {
    // インライン追加からの直接追加
    addSchool(school);
  };

  const handleDeleteSchool = (id: number) => {
    if (confirm("この学校を削除しますか？")) {
      removeSchool(id);
    }
  };

  // データエクスポート
  const handleExport = async () => {
    try {
      const json = exportData();
      const defaultName = `school-payment-backup-${new Date().toISOString().slice(0, 10)}.json`;

      const filePath = await save({
        defaultPath: defaultName,
        filters: [{ name: "JSON", extensions: ["json"] }],
      });

      if (filePath) {
        await writeTextFile(filePath, json);
        alert("データをエクスポートしました");
      }
    } catch (e) {
      console.error("Export error:", e);
      alert("エクスポートに失敗しました: " + String(e));
    }
  };

  // データインポート（Leanでバリデーション、エラー時も読み込んで修正可能に）
  const handleImportClick = async () => {
    try {
      const filePath = await open({
        filters: [{ name: "JSON", extensions: ["json"] }],
        multiple: false,
      });

      if (filePath && typeof filePath === "string") {
        const json = await readTextFile(filePath);
        const parsed = parseImportData(json);

        if (!parsed) {
          alert("インポートに失敗しました。ファイル形式を確認してください。");
          return;
        }

        if (parsed.length === 0) {
          alert("インポートに失敗しました。学校データが空です。");
          return;
        }

        // Lean APIでバリデーション
        try {
          await getRecommendation(parsed, today);
          // バリデーション成功
          setValidatedSchools(parsed);
          alert(`${parsed.length}校のデータをインポートしました`);
        } catch (validationError) {
          // Leanからのエラーメッセージを表示しつつ、データは読み込む
          const errorMsg = validationError instanceof Error
            ? validationError.message
            : String(validationError);

          // データを読み込んでカードで修正できるようにする
          setValidatedSchools(parsed);
          alert(
            `データを読み込みましたが、以下のエラーがあります:\n\n${errorMsg}\n\n` +
            `カードを編集して修正してください。`
          );
        }
      }
    } catch (e) {
      console.error("Import error:", e);
      alert("インポートに失敗しました: " + String(e));
    }
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

        {/* データ操作ボタン */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2 text-sm text-gray-600">
            {isLoading && <span>読み込み中...</span>}
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
          </div>
        </div>

        {/* エラー表示 */}
        {error && (
          <Card className="border-red-300 bg-red-50">
            <CardContent className="pt-6">
              <p className="text-red-600 whitespace-pre-line">{error}</p>
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
        {/* 志望校一覧 */}
        <div>
          <h2 className="text-lg font-semibold mb-4">🏫 志望校一覧</h2>
          <SchoolList
            schools={schools}
            onUpdatePassStatus={updatePassStatus}
            onUpdatePaymentStatus={updatePaymentStatus}
            onEdit={handleEditSchool}
            onDelete={handleDeleteSchool}
            onAdd={handleAddSchool}
            nextId={getNextId()}
            nextPriority={getNextPriority()}
          />
        </div>
      </main>

      {/* フッター */}
      <footer className="bg-white border-t mt-12">
        <div className="max-w-6xl mx-auto px-4 py-6 text-center text-sm text-gray-500 space-y-2">
          <a
            href="https://github.com/jl1nie/school-payment"
            target="_blank"
            rel="noopener noreferrer"
            className="font-medium hover:text-blue-600 hover:underline"
          >
            志望校支払いアドバイザー - Lean4形式検証によるビジネスロジック
          </a>
          <p className="text-xs text-gray-400">
            【免責事項】本ツールの情報は参考目的であり、実際の支払い判断は各大学の公式情報をご確認ください。
            本ツールの利用により生じた損害について、開発者は一切の責任を負いません。
          </p>
        </div>
      </footer>
    </div>
  );
}

export default App;
