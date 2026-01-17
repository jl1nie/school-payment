import { useMemo } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { SchoolWithState } from "@/types";
import { dayToDate } from "@/lib/date-utils";

interface CalendarProps {
  schools: SchoolWithState[];
  today: Date;
  selectedMonth?: Date;
  onMonthChange?: (month: Date) => void;
  onDateSelect?: (date: Date) => void;
}

// 学校ごとの色
const SCHOOL_COLORS = [
  { bg: "bg-blue-100", border: "border-blue-400", text: "text-blue-700" },
  { bg: "bg-green-100", border: "border-green-400", text: "text-green-700" },
  { bg: "bg-purple-100", border: "border-purple-400", text: "text-purple-700" },
  { bg: "bg-orange-100", border: "border-orange-400", text: "text-orange-700" },
  { bg: "bg-pink-100", border: "border-pink-400", text: "text-pink-700" },
  { bg: "bg-teal-100", border: "border-teal-400", text: "text-teal-700" },
  { bg: "bg-yellow-100", border: "border-yellow-400", text: "text-yellow-700" },
  { bg: "bg-red-100", border: "border-red-400", text: "text-red-700" },
];

// イベントタイプ
type EventType = "exam" | "result" | "enrollmentFee" | "tuition";

interface CalendarEvent {
  schoolId: number;
  schoolName: string;
  type: EventType;
  date: Date;
  colorIndex: number;
}

const EVENT_ICONS: Record<EventType, { icon: string; label: string }> = {
  exam: { icon: "★", label: "受験日" },
  result: { icon: "○", label: "発表日" },
  enrollmentFee: { icon: "◎", label: "入学金期限" },
  tuition: { icon: "▲", label: "授業料期限" },
};

export function Calendar({
  schools,
  today,
  selectedMonth,
  onMonthChange,
  onDateSelect,
}: CalendarProps) {
  const currentMonth = selectedMonth || today;

  // イベントを生成（YYYYMMDD形式の整数からDateに変換）
  const events = useMemo(() => {
    const result: CalendarEvent[] = [];
    schools.forEach((school, index) => {
      const colorIndex = index % SCHOOL_COLORS.length;
      const types: { type: EventType; day: number }[] = [
        { type: "exam", day: school.examDate },
        { type: "result", day: school.resultDate },
        { type: "enrollmentFee", day: school.enrollmentFeeDeadline },
        { type: "tuition", day: school.tuitionDeadline },
      ];
      types.forEach(({ type, day }) => {
        result.push({
          schoolId: school.id,
          schoolName: school.name,
          type,
          date: dayToDate(day),
          colorIndex,
        });
      });
    });
    return result;
  }, [schools]);

  // カレンダーの日付を生成
  const calendarDays = useMemo(() => {
    const year = currentMonth.getFullYear();
    const month = currentMonth.getMonth();

    // 月の最初と最後の日
    const firstDay = new Date(year, month, 1);
    const lastDay = new Date(year, month + 1, 0);

    // カレンダーの開始日（前月の日曜日から）
    const startDate = new Date(firstDay);
    startDate.setDate(startDate.getDate() - firstDay.getDay());

    // カレンダーの終了日（次月の土曜日まで）
    const endDate = new Date(lastDay);
    endDate.setDate(endDate.getDate() + (6 - lastDay.getDay()));

    const days: Date[] = [];
    const current = new Date(startDate);
    while (current <= endDate) {
      days.push(new Date(current));
      current.setDate(current.getDate() + 1);
    }
    return days;
  }, [currentMonth]);

  // 日付ごとのイベントをマップ
  const eventsByDate = useMemo(() => {
    const map = new Map<string, CalendarEvent[]>();
    events.forEach((event) => {
      const key = event.date.toDateString();
      if (!map.has(key)) {
        map.set(key, []);
      }
      map.get(key)!.push(event);
    });
    return map;
  }, [events]);

  const goToPrevMonth = () => {
    const prev = new Date(currentMonth);
    prev.setMonth(prev.getMonth() - 1);
    onMonthChange?.(prev);
  };

  const goToNextMonth = () => {
    const next = new Date(currentMonth);
    next.setMonth(next.getMonth() + 1);
    onMonthChange?.(next);
  };

  const isToday = (date: Date) => date.toDateString() === today.toDateString();
  const isCurrentMonth = (date: Date) =>
    date.getMonth() === currentMonth.getMonth();

  return (
    <Card>
      <CardHeader className="pb-2">
        <div className="flex items-center justify-between">
          <button
            onClick={goToPrevMonth}
            className="px-3 py-1 rounded hover:bg-gray-100"
          >
            ◀
          </button>
          <CardTitle>
            {currentMonth.getFullYear()}年{currentMonth.getMonth() + 1}月
          </CardTitle>
          <button
            onClick={goToNextMonth}
            className="px-3 py-1 rounded hover:bg-gray-100"
          >
            ▶
          </button>
        </div>
      </CardHeader>
      <CardContent>
        {/* 凡例 */}
        <div className="mb-4 flex flex-wrap gap-4 text-sm">
          <div className="flex items-center gap-1">
            <span className="font-bold">★</span>
            <span>受験日</span>
          </div>
          <div className="flex items-center gap-1">
            <span className="font-bold">○</span>
            <span>発表日</span>
          </div>
          <div className="flex items-center gap-1">
            <span className="font-bold">◎</span>
            <span>入学金期限</span>
          </div>
          <div className="flex items-center gap-1">
            <span className="font-bold">▲</span>
            <span>授業料期限</span>
          </div>
        </div>

        {/* 学校の色凡例 */}
        {schools.length > 0 && (
          <div className="mb-4 flex flex-wrap gap-2 text-sm">
            {schools.map((school, index) => {
              const color = SCHOOL_COLORS[index % SCHOOL_COLORS.length];
              return (
                <span
                  key={school.id}
                  className={`px-2 py-0.5 rounded ${color.bg} ${color.text} text-xs`}
                >
                  {school.name}
                </span>
              );
            })}
          </div>
        )}

        {/* カレンダーグリッド */}
        <div className="grid grid-cols-7 gap-1">
          {/* 曜日ヘッダー */}
          {["日", "月", "火", "水", "木", "金", "土"].map((day, i) => (
            <div
              key={day}
              className={`text-center text-sm font-medium py-2 ${
                i === 0 ? "text-red-500" : i === 6 ? "text-blue-500" : ""
              }`}
            >
              {day}
            </div>
          ))}

          {/* 日付セル */}
          {calendarDays.map((date, index) => {
            const dateEvents = eventsByDate.get(date.toDateString()) || [];
            const dayOfWeek = date.getDay();

            return (
              <div
                key={index}
                onClick={() => onDateSelect?.(date)}
                className={`min-h-[80px] p-1 border rounded cursor-pointer hover:bg-gray-100 transition-colors ${
                  isToday(date)
                    ? "border-2 border-red-500 bg-red-50 hover:bg-red-100"
                    : "border-gray-200"
                } ${!isCurrentMonth(date) ? "bg-gray-50 opacity-50" : ""}`}
              >
                <div
                  className={`text-sm font-medium mb-1 ${
                    dayOfWeek === 0
                      ? "text-red-500"
                      : dayOfWeek === 6
                      ? "text-blue-500"
                      : ""
                  }`}
                >
                  {date.getDate()}
                  {isToday(date) && (
                    <span className="ml-1 text-xs text-red-500">設定日</span>
                  )}
                </div>
                <div className="space-y-0.5">
                  {dateEvents.map((event, i) => {
                    const color = SCHOOL_COLORS[event.colorIndex];
                    const icon = EVENT_ICONS[event.type];
                    return (
                      <div
                        key={i}
                        className={`text-xs px-1 py-0.5 rounded truncate ${color.bg} ${color.text}`}
                        title={`${event.schoolName} - ${icon.label}`}
                      >
                        {icon.icon}
                        <span className="ml-0.5">{event.schoolName}</span>
                      </div>
                    );
                  })}
                </div>
              </div>
            );
          })}
        </div>
      </CardContent>
    </Card>
  );
}
