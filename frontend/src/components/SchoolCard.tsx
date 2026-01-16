import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { PaymentStatusBadge } from "@/components/StatusBadges";
import type { SchoolWithState, PassStatus } from "@/types";
import { dayToDate, formatDate } from "@/lib/date-utils";

interface SchoolCardProps {
  school: SchoolWithState;
  colorIndex?: number;
  baseYear?: number;
  onUpdatePassStatus: (id: number, status: PassStatus) => void;
  onUpdatePaymentStatus: (
    id: number,
    updates: { enrollmentFeePaid?: boolean; tuitionPaid?: boolean }
  ) => void;
  onEdit: (school: SchoolWithState) => void;
  onDelete: (id: number) => void;
}

// 学校ごとの色（Calendarと同じ）
const SCHOOL_COLORS = [
  { bg: "bg-blue-50", border: "border-blue-400", accent: "bg-blue-500" },
  { bg: "bg-green-50", border: "border-green-400", accent: "bg-green-500" },
  { bg: "bg-purple-50", border: "border-purple-400", accent: "bg-purple-500" },
  { bg: "bg-orange-50", border: "border-orange-400", accent: "bg-orange-500" },
  { bg: "bg-pink-50", border: "border-pink-400", accent: "bg-pink-500" },
  { bg: "bg-teal-50", border: "border-teal-400", accent: "bg-teal-500" },
  { bg: "bg-yellow-50", border: "border-yellow-400", accent: "bg-yellow-500" },
  { bg: "bg-red-50", border: "border-red-400", accent: "bg-red-500" },
];

// 合否ステータスボタンの設定
const PASS_STATUS_CONFIG: Record<
  PassStatus,
  { label: string; className: string; activeClassName: string }
> = {
  notYetAnnounced: {
    label: "未発表",
    className: "border-gray-300 text-gray-500 hover:bg-gray-50",
    activeClassName: "bg-gray-500 text-white border-gray-500",
  },
  passed: {
    label: "合格",
    className: "border-green-300 text-green-600 hover:bg-green-50",
    activeClassName: "bg-green-500 text-white border-green-500",
  },
  failed: {
    label: "不合格",
    className: "border-red-300 text-red-600 hover:bg-red-50",
    activeClassName: "bg-red-500 text-white border-red-500",
  },
  cancelled: {
    label: "取消",
    className: "border-gray-300 text-gray-400",
    activeClassName: "bg-gray-400 text-white border-gray-400",
  },
};

export function SchoolCard({
  school,
  colorIndex = 0,
  baseYear,
  onUpdatePassStatus,
  onUpdatePaymentStatus,
  onEdit,
  onDelete,
}: SchoolCardProps) {
  const formatAmount = (amount: number) =>
    `¥${amount.toLocaleString("ja-JP")}`;

  const isCancelled = school.passStatus === "cancelled";
  const color = SCHOOL_COLORS[colorIndex % SCHOOL_COLORS.length];

  const handlePassStatusClick = (status: PassStatus) => {
    if (!isCancelled && status !== "cancelled") {
      onUpdatePassStatus(school.id, status);
    }
  };

  return (
    <Card
      className={`${isCancelled ? "opacity-60" : ""} border-l-4 ${color.border}`}
    >
      <CardHeader className="pb-2">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <span
              className={`w-3 h-3 rounded-full ${color.accent}`}
              title={`第${school.priority}志望`}
            />
            <h3
              className={`text-lg font-semibold ${
                isCancelled ? "line-through text-gray-500" : ""
              }`}
            >
              {school.name}
            </h3>
            <span className="text-sm text-gray-400">
              第{school.priority}志望
            </span>
          </div>
          <PaymentStatusBadge
            enrollmentFeePaid={school.enrollmentFeePaid}
            tuitionPaid={school.tuitionPaid}
          />
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        {/* 合否選択ボタン */}
        <div className="space-y-2">
          <h4 className="text-sm font-medium text-gray-600">合否状況</h4>
          <div className="flex gap-2">
            {(["notYetAnnounced", "passed", "failed"] as PassStatus[]).map(
              (status) => {
                const config = PASS_STATUS_CONFIG[status];
                const isActive = school.passStatus === status;
                return (
                  <button
                    key={status}
                    onClick={() => handlePassStatusClick(status)}
                    disabled={isCancelled}
                    className={`px-4 py-2 rounded-lg border-2 font-medium transition-all ${
                      isActive ? config.activeClassName : config.className
                    } ${isCancelled ? "cursor-not-allowed opacity-50" : ""}`}
                  >
                    {config.label}
                  </button>
                );
              }
            )}
          </div>
        </div>

        {/* 日程情報 */}
        <div className="space-y-2">
          <h4 className="text-sm font-medium text-gray-600">日程</h4>
          <div className="grid grid-cols-2 gap-2 text-sm">
            <div className="flex items-center gap-2">
              <span className="text-lg">★</span>
              <div>
                <span className="text-gray-500">受験日</span>
                <div className="font-medium">
                  {formatDate(dayToDate(school.examDate, baseYear))}
                </div>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-lg">○</span>
              <div>
                <span className="text-gray-500">発表日</span>
                <div className="font-medium">
                  {formatDate(dayToDate(school.resultDate, baseYear))}
                </div>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-lg">◎</span>
              <div>
                <span className="text-gray-500">入学金期限</span>
                <div className="font-medium">
                  {formatDate(dayToDate(school.enrollmentFeeDeadline, baseYear))}
                </div>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-lg">▲</span>
              <div>
                <span className="text-gray-500">授業料期限</span>
                <div className="font-medium">
                  {formatDate(dayToDate(school.tuitionDeadline, baseYear))}
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* 費用・支払い情報 */}
        <div className="space-y-2 pt-2 border-t">
          <h4 className="text-sm font-medium text-gray-600">費用・支払い</h4>
          <div className="grid grid-cols-2 gap-4">
            <div className="flex items-center justify-between p-2 rounded bg-gray-50">
              <div>
                <div className="text-xs text-gray-500">入学金</div>
                <div className="font-medium">
                  {formatAmount(school.enrollmentFee)}
                </div>
              </div>
              <Checkbox
                checked={school.enrollmentFeePaid}
                onChange={(e) =>
                  onUpdatePaymentStatus(school.id, {
                    enrollmentFeePaid: e.target.checked,
                  })
                }
                disabled={isCancelled || school.passStatus !== "passed"}
              />
            </div>
            <div className="flex items-center justify-between p-2 rounded bg-gray-50">
              <div>
                <div className="text-xs text-gray-500">授業料</div>
                <div className="font-medium">
                  {formatAmount(school.tuition)}
                </div>
              </div>
              <Checkbox
                checked={school.tuitionPaid}
                onChange={(e) =>
                  onUpdatePaymentStatus(school.id, {
                    tuitionPaid: e.target.checked,
                  })
                }
                disabled={isCancelled || !school.enrollmentFeePaid}
              />
            </div>
          </div>
        </div>

        {/* アクションボタン */}
        <div className="flex justify-end gap-2 pt-2">
          <Button variant="outline" size="sm" onClick={() => onEdit(school)}>
            編集
          </Button>
          <Button
            variant="destructive"
            size="sm"
            onClick={() => onDelete(school.id)}
          >
            削除
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
