import { useState } from "react";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { DatePicker } from "@/components/DatePicker";
import { SchoolCard } from "@/components/SchoolCard";
import type { SchoolWithState, PassStatus } from "@/types";
import { dateToDay } from "@/lib/date-utils";

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

interface SchoolListProps {
  schools: SchoolWithState[];
  onUpdatePassStatus: (id: number, status: PassStatus) => void;
  onUpdatePaymentStatus: (
    id: number,
    updates: { enrollmentFeePaid?: boolean; tuitionPaid?: boolean }
  ) => void;
  onEdit: (school: SchoolWithState) => void;
  onDelete: (id: number) => void;
  onAdd: (school: SchoolWithState) => void;
  nextId: number;
  nextPriority: number;
}

export function SchoolList({
  schools,
  onUpdatePassStatus,
  onUpdatePaymentStatus,
  onEdit,
  onDelete,
  onAdd,
  nextId,
  nextPriority,
}: SchoolListProps) {
  const [isAdding, setIsAdding] = useState(false);
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
    name: "",
    priority: nextPriority,
    examDate: null,
    resultDate: null,
    enrollmentFeeDeadline: null,
    tuitionDeadline: null,
    enrollmentFee: "",
    tuition: "",
  });
  const [errors, setErrors] = useState<FormErrors>({});

  const handleStartAdd = () => {
    setEditData({
      name: "",
      priority: nextPriority,
      examDate: null,
      resultDate: null,
      enrollmentFeeDeadline: null,
      tuitionDeadline: null,
      enrollmentFee: "",
      tuition: "",
    });
    setErrors({});
    setIsAdding(true);
  };

  const handleCancelAdd = () => {
    setIsAdding(false);
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

    const newSchool: SchoolWithState = {
      id: nextId,
      name: editData.name.trim(),
      priority: editData.priority,
      examDate: dateToDay(editData.examDate!),
      resultDate: dateToDay(editData.resultDate!),
      enrollmentFeeDeadline: dateToDay(editData.enrollmentFeeDeadline!),
      tuitionDeadline: dateToDay(editData.tuitionDeadline!),
      enrollmentFee: parseInt(editData.enrollmentFee),
      tuition: parseInt(editData.tuition),
      passStatus: "notYetAnnounced",
      enrollmentFeePaid: false,
      tuitionPaid: false,
    };

    onAdd(newSchool);
    setIsAdding(false);
  };

  // 志望順位でソート
  const sortedSchools = [...schools].sort((a, b) => a.priority - b.priority);

  return (
    <div className="grid gap-4 md:grid-cols-2">
      {sortedSchools.map((school, index) => (
        <SchoolCard
          key={school.id}
          school={school}
          colorIndex={index}
          onUpdatePassStatus={onUpdatePassStatus}
          onUpdatePaymentStatus={onUpdatePaymentStatus}
          onEdit={onEdit}
          onDelete={onDelete}
        />
      ))}
      {isAdding ? (
        <Card className="border-l-4 border-gray-400">
          <CardHeader className="pb-2">
            <div className="flex items-center gap-2">
              <span className="w-3 h-3 rounded-full bg-gray-400" />
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
              <Button variant="outline" size="sm" onClick={handleCancelAdd}>
                キャンセル
              </Button>
              <Button size="sm" onClick={handleSave}>
                追加
              </Button>
            </div>
          </CardContent>
        </Card>
      ) : (
        <button
          onClick={handleStartAdd}
          className="border-2 border-dashed border-gray-300 rounded-lg p-8 flex flex-col items-center justify-center gap-2 text-gray-500 hover:border-gray-400 hover:text-gray-600 hover:bg-gray-50 transition-colors min-h-[200px]"
        >
          <span className="text-4xl">+</span>
          <span className="font-medium">学校を追加</span>
        </button>
      )}
    </div>
  );
}
