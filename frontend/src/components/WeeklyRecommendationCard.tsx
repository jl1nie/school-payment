import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import type { GetWeeklyRecommendationsResult, SchoolWithState, DailyRecommendation } from "@/types";
import { dayToDate } from "@/lib/date-utils";

interface WeeklyRecommendationCardProps {
  result: GetWeeklyRecommendationsResult;
  schools: SchoolWithState[];
  baseYear: number;
}

export function WeeklyRecommendationCard({
  result,
  schools,
  baseYear,
}: WeeklyRecommendationCardProps) {
  const getSchoolName = (schoolId: number | undefined): string => {
    if (schoolId === undefined) return "";
    const school = schools.find((s) => s.id === schoolId);
    return school?.name ?? `学校ID: ${schoolId}`;
  };

  const formatAmount = (schoolId: number | undefined, type: string): string => {
    if (schoolId === undefined) return "";
    const school = schools.find((s) => s.id === schoolId);
    if (!school) return "";
    const amount =
      type === "payEnrollmentFee" ? school.enrollmentFee : school.tuition;
    return `¥${amount.toLocaleString("ja-JP")}`;
  };

  const getActionDescription = (
    actionType: string,
    schoolId?: number
  ): string => {
    switch (actionType) {
      case "payEnrollmentFee":
        return `${getSchoolName(schoolId)}の入学金を支払う`;
      case "payTuition":
        return `${getSchoolName(schoolId)}の授業料を支払う`;
      case "doNothing":
        return "支払いの必要なし";
      default:
        return "不明なアクション";
    }
  };

  const formatDate = (day: number): string => {
    const date = dayToDate(day, baseYear);
    return `${date.getMonth() + 1}/${date.getDate()}(${["日", "月", "火", "水", "木", "金", "土"][date.getDay()]})`;
  };

  // アクションがある日だけをフィルタ
  const actionDays = result.recommendations.filter(
    (rec) => rec.result.action.type !== "doNothing"
  );

  // 発表日に該当する日の一覧
  const announcementDays = new Set(result.upcomingAnnouncements.map((a) => a.resultDay));

  // doNothingでない日がない場合
  const hasNoActions = actionDays.length === 0;

  return (
    <div className="space-y-4">
      {/* Lean側からの注記 */}
      {result.note && (
        <Card className="border-blue-200 bg-blue-50">
          <CardContent className="py-3">
            <p className="text-sm text-blue-800 font-medium mb-1">
              📢 注意:
            </p>
            <p className="text-sm text-blue-700">{result.note}</p>
            {result.upcomingAnnouncements.length > 0 && (
              <ul className="text-sm text-blue-700 list-disc list-inside mt-2">
                {result.upcomingAnnouncements.map((a) => (
                  <li key={a.schoolId}>
                    {formatDate(a.resultDay)}: {a.schoolName}の合格発表
                  </li>
                ))}
              </ul>
            )}
          </CardContent>
        </Card>
      )}

      {/* アクションなしの場合 */}
      {hasNoActions && (
        <Card>
          <CardContent className="py-6 text-center">
            <p className="text-gray-600">
              この1週間で必要な支払いアクションはありません。
            </p>
          </CardContent>
        </Card>
      )}

      {/* 1週間分のアクション */}
      {!hasNoActions && (
        <div className="space-y-3">
          <h3 className="text-sm font-medium text-gray-600">
            今後1週間の推奨アクション
          </h3>
          {result.recommendations.map((rec) => (
            <DailyCard
              key={rec.day}
              recommendation={rec}
              schools={schools}
              baseYear={baseYear}
              getActionDescription={getActionDescription}
              formatAmount={formatAmount}
              formatDate={formatDate}
              isAnnouncementDay={announcementDays.has(rec.day)}
              announcements={result.upcomingAnnouncements.filter(
                (a) => a.resultDay === rec.day
              )}
            />
          ))}
        </div>
      )}

      {/* 合計支払い額 */}
      {!hasNoActions && (
        <TotalPayments
          recommendations={result.recommendations}
          schools={schools}
        />
      )}
    </div>
  );
}

interface DailyCardProps {
  recommendation: DailyRecommendation;
  schools: SchoolWithState[];
  baseYear: number;
  getActionDescription: (actionType: string, schoolId?: number) => string;
  formatAmount: (schoolId: number | undefined, type: string) => string;
  formatDate: (day: number) => string;
  isAnnouncementDay: boolean;
  announcements: { schoolId: number; schoolName: string; resultDay: number }[];
}

function DailyCard({
  recommendation,
  getActionDescription,
  formatAmount,
  formatDate,
  isAnnouncementDay,
  announcements,
}: DailyCardProps) {
  const { day, result } = recommendation;
  const { action, reason, urgency } = result;
  const isDoNothing = action.type === "doNothing";

  // doNothingで発表もない日は省略
  if (isDoNothing && !isAnnouncementDay) {
    return null;
  }

  return (
    <Card
      className={
        urgency === 0
          ? "border-red-300 bg-red-50"
          : urgency <= 3
          ? "border-yellow-300 bg-yellow-50"
          : isDoNothing
          ? "bg-gray-50"
          : ""
      }
    >
      <CardHeader className="py-2 px-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <span className="font-medium">{formatDate(day)}</span>
            {isAnnouncementDay && (
              <span className="text-xs bg-blue-100 text-blue-700 px-2 py-0.5 rounded">
                📢 発表あり
              </span>
            )}
          </div>
          {!isDoNothing && (
            <Badge variant={urgency <= 1 ? "destructive" : urgency <= 3 ? "warning" : "default"}>
              {action.type === "payEnrollmentFee" ? "💰 入学金" : "💰 授業料"}
            </Badge>
          )}
        </div>
      </CardHeader>
      <CardContent className="py-2 px-4">
        {isDoNothing ? (
          <p className="text-sm text-gray-500">支払いアクションなし</p>
        ) : (
          <>
            <p className="font-medium">
              {getActionDescription(action.type, action.schoolId)}
            </p>
            {action.schoolId !== undefined && (
              <p className="text-sm text-gray-600">
                金額: {formatAmount(action.schoolId, action.type)}
              </p>
            )}
            <p className="text-sm text-gray-600 mt-1">{reason}</p>
          </>
        )}
        {isAnnouncementDay && announcements.length > 0 && (
          <p className="text-sm text-blue-600 mt-1">
            {announcements.map((a) => a.schoolName).join(", ")}の結果発表日
          </p>
        )}
      </CardContent>
    </Card>
  );
}

interface TotalPaymentsProps {
  recommendations: DailyRecommendation[];
  schools: SchoolWithState[];
}

function TotalPayments({ recommendations, schools }: TotalPaymentsProps) {
  // ユニークな支払いアクションを集計
  const payments = new Map<string, { schoolId: number; type: string }>();

  for (const rec of recommendations) {
    const { action } = rec.result;
    if (action.type !== "doNothing" && action.schoolId !== undefined) {
      const key = `${action.schoolId}-${action.type}`;
      if (!payments.has(key)) {
        payments.set(key, { schoolId: action.schoolId, type: action.type });
      }
    }
  }

  if (payments.size === 0) return null;

  let total = 0;
  const paymentList: { name: string; amount: number; type: string }[] = [];

  payments.forEach(({ schoolId, type }) => {
    const school = schools.find((s) => s.id === schoolId);
    if (school) {
      const amount =
        type === "payEnrollmentFee" ? school.enrollmentFee : school.tuition;
      total += amount;
      paymentList.push({
        name: school.name,
        amount,
        type: type === "payEnrollmentFee" ? "入学金" : "授業料",
      });
    }
  });

  return (
    <Card className="bg-gray-100">
      <CardHeader className="py-2 px-4">
        <CardTitle className="text-sm">1週間の支払い予定</CardTitle>
      </CardHeader>
      <CardContent className="py-2 px-4">
        <ul className="text-sm space-y-1">
          {paymentList.map((p, i) => (
            <li key={i} className="flex justify-between">
              <span>
                {p.name}（{p.type}）
              </span>
              <span>¥{p.amount.toLocaleString("ja-JP")}</span>
            </li>
          ))}
        </ul>
        <div className="border-t mt-2 pt-2 flex justify-between font-medium">
          <span>合計</span>
          <span>¥{total.toLocaleString("ja-JP")}</span>
        </div>
      </CardContent>
    </Card>
  );
}
