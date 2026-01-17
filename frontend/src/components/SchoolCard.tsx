import { useState } from "react";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { DatePicker } from "@/components/DatePicker";
import { PaymentStatusBadge } from "@/components/StatusBadges";
import type { SchoolWithState, PassStatus } from "@/types";
import { dayToDate, dateToDay, formatDate } from "@/lib/date-utils";

interface FormErrors {
  name?: string;
  priority?: string;
  examDate?: string;
  resultDate?: string;
  enrollmentFeeDeadline?: string;
  tuitionDeadline?: string;
  enrollmentFee?: string;
  tuition?: string;
}

interface SchoolCardProps {
  school: SchoolWithState;
  colorIndex?: number;
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
  onUpdatePassStatus,
  onUpdatePaymentStatus,
  onEdit,
  onDelete,
}: SchoolCardProps) {
  const [isEditing, setIsEditing] = useState(false);
  const [editData, setEditData] = useState<{
    name: string;
    priority: number;
    examDate: Date | null;
    resultDate: Date | null;
    enrollmentFeeDeadline: Date | null;
    tuitionDeadline: Date | null;
    enrollmentFee: string;
    tuition: string;
  }>({
    name: school.name,
    priority: school.priority,
    examDate: dayToDate(school.examDate),
    resultDate: dayToDate(school.resultDate),
    enrollmentFeeDeadline: dayToDate(school.enrollmentFeeDeadline),
    tuitionDeadline: dayToDate(school.tuitionDeadline),
    enrollmentFee: school.enrollmentFee.toString(),
    tuition: school.tuition.toString(),
  });
  const [errors, setErrors] = useState<FormErrors>({});

  const formatAmount = (amount: number) =>
    `¥${amount.toLocaleString("ja-JP")}`;

  const isCancelled = school.passStatus === "cancelled";
  const color = SCHOOL_COLORS[colorIndex % SCHOOL_COLORS.length];

  const handlePassStatusClick = (status: PassStatus) => {
    if (status !== "cancelled") {
      onUpdatePassStatus(school.id, status);
    }
  };

  const handleStartEdit = () => {
    setEditData({
      name: school.name,
      priority: school.priority,
      examDate: dayToDate(school.examDate),
      resultDate: dayToDate(school.resultDate),
      enrollmentFeeDeadline: dayToDate(school.enrollmentFeeDeadline),
      tuitionDeadline: dayToDate(school.tuitionDeadline),
      enrollmentFee: school.enrollmentFee.toString(),
      tuition: school.tuition.toString(),
    });
    setErrors({});
    setIsEditing(true);
  };

  const handleCancelEdit = () => {
    setIsEditing(false);
    setErrors({});
  };

  const validate = (): boolean => {
    const newErrors: FormErrors = {};

    if (!editData.name.trim()) {
      newErrors.name = "大学名を入力してください";
    }

    if (editData.priority < 1) {
      newErrors.priority = "志望順位は1以上にしてください";
    }

    if (!editData.examDate) {
      newErrors.examDate = "受験日を選択してください";
    }

    if (!editData.resultDate) {
      newErrors.resultDate = "発表日を選択してください";
    } else if (editData.examDate && editData.resultDate < editData.examDate) {
      newErrors.resultDate = "発表日は受験日以降にしてください";
    }

    if (!editData.enrollmentFeeDeadline) {
      newErrors.enrollmentFeeDeadline = "入学金納付期限を選択してください";
    } else if (editData.resultDate && editData.enrollmentFeeDeadline < editData.resultDate) {
      newErrors.enrollmentFeeDeadline = "入学金納付期限は発表日以降にしてください";
    }

    if (!editData.tuitionDeadline) {
      newErrors.tuitionDeadline = "授業料納付期限を選択してください";
    } else if (editData.enrollmentFeeDeadline && editData.tuitionDeadline < editData.enrollmentFeeDeadline) {
      newErrors.tuitionDeadline = "授業料納付期限は入学金納付期限以降にしてください";
    }

    const enrollmentFeeNum = parseInt(editData.enrollmentFee);
    if (!editData.enrollmentFee || isNaN(enrollmentFeeNum) || enrollmentFeeNum <= 0) {
      newErrors.enrollmentFee = "入学金は正の数で入力してください";
    }

    const tuitionNum = parseInt(editData.tuition);
    if (!editData.tuition || isNaN(tuitionNum) || tuitionNum <= 0) {
      newErrors.tuition = "授業料は正の数で入力してください";
    } else if (enrollmentFeeNum >= tuitionNum) {
      newErrors.tuition = "授業料は入学金より大きくしてください";
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSave = () => {
    if (!validate()) return;

    const updatedSchool: SchoolWithState = {
      ...school,
      name: editData.name.trim(),
      priority: editData.priority,
      examDate: dateToDay(editData.examDate!),
      resultDate: dateToDay(editData.resultDate!),
      enrollmentFeeDeadline: dateToDay(editData.enrollmentFeeDeadline!),
      tuitionDeadline: dateToDay(editData.tuitionDeadline!),
      enrollmentFee: parseInt(editData.enrollmentFee),
      tuition: parseInt(editData.tuition),
    };

    onEdit(updatedSchool);
    setIsEditing(false);
  };

  if (isEditing) {
    return (
      <Card className={`border-l-4 ${color.border}`}>
        <CardHeader className="pb-2">
          <div className="flex items-center gap-2">
            <span className={`w-3 h-3 rounded-full ${color.accent}`} />
            <Input
              value={editData.name}
              onChange={(e) => setEditData({ ...editData, name: e.target.value })}
              placeholder="大学名"
              className="text-lg font-semibold"
            />
          </div>
          {errors.name && <p className="text-red-500 text-sm">{errors.name}</p>}
        </CardHeader>
        <CardContent className="space-y-4">
          {/* 志望順位 */}
          <div>
            <label className="block text-sm font-medium text-gray-600 mb-1">
              志望順位
            </label>
            <Input
              type="number"
              min="1"
              value={editData.priority}
              onChange={(e) => setEditData({ ...editData, priority: parseInt(e.target.value) || 1 })}
              className="w-24"
            />
            {errors.priority && <p className="text-red-500 text-sm">{errors.priority}</p>}
          </div>

          {/* 日程情報 */}
          <div className="space-y-2">
            <h4 className="text-sm font-medium text-gray-600">日程</h4>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <DatePicker
                  label="受験日"
                  value={editData.examDate}
                  onChange={(date) => setEditData({ ...editData, examDate: date })}
                />
                {errors.examDate && <p className="text-red-500 text-sm">{errors.examDate}</p>}
              </div>
              <div>
                <DatePicker
                  label="発表日"
                  value={editData.resultDate}
                  onChange={(date) => setEditData({ ...editData, resultDate: date })}
                />
                {errors.resultDate && <p className="text-red-500 text-sm">{errors.resultDate}</p>}
              </div>
              <div>
                <DatePicker
                  label="入学金納付期限"
                  value={editData.enrollmentFeeDeadline}
                  onChange={(date) => setEditData({ ...editData, enrollmentFeeDeadline: date })}
                />
                {errors.enrollmentFeeDeadline && <p className="text-red-500 text-sm">{errors.enrollmentFeeDeadline}</p>}
              </div>
              <div>
                <DatePicker
                  label="授業料納付期限"
                  value={editData.tuitionDeadline}
                  onChange={(date) => setEditData({ ...editData, tuitionDeadline: date })}
                />
                {errors.tuitionDeadline && <p className="text-red-500 text-sm">{errors.tuitionDeadline}</p>}
              </div>
            </div>
          </div>

          {/* 費用情報 */}
          <div className="space-y-2">
            <h4 className="text-sm font-medium text-gray-600">費用</h4>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-xs text-gray-500 mb-1">入学金（円）</label>
                <Input
                  type="number"
                  min="1"
                  value={editData.enrollmentFee}
                  onChange={(e) => setEditData({ ...editData, enrollmentFee: e.target.value })}
                />
                {errors.enrollmentFee && <p className="text-red-500 text-sm">{errors.enrollmentFee}</p>}
              </div>
              <div>
                <label className="block text-xs text-gray-500 mb-1">授業料（円）</label>
                <Input
                  type="number"
                  min="1"
                  value={editData.tuition}
                  onChange={(e) => setEditData({ ...editData, tuition: e.target.value })}
                />
                {errors.tuition && <p className="text-red-500 text-sm">{errors.tuition}</p>}
              </div>
            </div>
          </div>

          {/* 保存/キャンセルボタン */}
          <div className="flex justify-end gap-2 pt-2">
            <Button variant="outline" size="sm" onClick={handleCancelEdit}>
              キャンセル
            </Button>
            <Button size="sm" onClick={handleSave}>
              保存
            </Button>
          </div>
        </CardContent>
      </Card>
    );
  }

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
                    className={`px-4 py-2 rounded-lg border-2 font-medium transition-all ${
                      isActive ? config.activeClassName : config.className
                    }`}
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
                  {formatDate(dayToDate(school.examDate))}
                </div>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-lg">○</span>
              <div>
                <span className="text-gray-500">発表日</span>
                <div className="font-medium">
                  {formatDate(dayToDate(school.resultDate))}
                </div>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-lg">◎</span>
              <div>
                <span className="text-gray-500">入学金納付期限</span>
                <div className="font-medium">
                  {formatDate(dayToDate(school.enrollmentFeeDeadline))}
                </div>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-lg">▲</span>
              <div>
                <span className="text-gray-500">授業料納付期限</span>
                <div className="font-medium">
                  {formatDate(dayToDate(school.tuitionDeadline))}
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
          <Button variant="outline" size="sm" onClick={handleStartEdit}>
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
