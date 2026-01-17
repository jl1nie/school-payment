import { useState, useEffect } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { DatePicker } from "@/components/DatePicker";
import type { SchoolWithState } from "@/types";
import { dateToDay, dayToDate } from "@/lib/date-utils";

interface SchoolFormProps {
  school?: SchoolWithState | null;
  nextId: number;
  nextPriority: number;
  onSave: (school: SchoolWithState) => void;
  onCancel: () => void;
}

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

export function SchoolForm({
  school,
  nextId,
  nextPriority,
  onSave,
  onCancel,
}: SchoolFormProps) {
  const isEditing = !!school;

  const [name, setName] = useState(school?.name ?? "");
  const [priority, setPriority] = useState(school?.priority ?? nextPriority);
  const [examDate, setExamDate] = useState<Date | null>(
    school ? dayToDate(school.examDate) : null
  );
  const [resultDate, setResultDate] = useState<Date | null>(
    school ? dayToDate(school.resultDate) : null
  );
  const [enrollmentFeeDeadline, setEnrollmentFeeDeadline] =
    useState<Date | null>(
      school ? dayToDate(school.enrollmentFeeDeadline) : null
    );
  const [tuitionDeadline, setTuitionDeadline] = useState<Date | null>(
    school ? dayToDate(school.tuitionDeadline) : null
  );
  const [enrollmentFee, setEnrollmentFee] = useState(
    school?.enrollmentFee?.toString() ?? ""
  );
  const [tuition, setTuition] = useState(school?.tuition?.toString() ?? "");
  const [errors, setErrors] = useState<FormErrors>({});

  useEffect(() => {
    if (school) {
      setName(school.name);
      setPriority(school.priority);
      setExamDate(dayToDate(school.examDate));
      setResultDate(dayToDate(school.resultDate));
      setEnrollmentFeeDeadline(dayToDate(school.enrollmentFeeDeadline));
      setTuitionDeadline(dayToDate(school.tuitionDeadline));
      setEnrollmentFee(school.enrollmentFee.toString());
      setTuition(school.tuition.toString());
    }
  }, [school]);

  const validate = (): boolean => {
    const newErrors: FormErrors = {};

    if (!name.trim()) {
      newErrors.name = "大学名を入力してください";
    }

    if (priority < 1) {
      newErrors.priority = "志望順位は1以上にしてください";
    }

    if (!examDate) {
      newErrors.examDate = "受験日を選択してください";
    }

    if (!resultDate) {
      newErrors.resultDate = "発表日を選択してください";
    } else if (examDate && resultDate < examDate) {
      newErrors.resultDate = "発表日は受験日以降にしてください";
    }

    if (!enrollmentFeeDeadline) {
      newErrors.enrollmentFeeDeadline = "入学金期限を選択してください";
    } else if (resultDate && enrollmentFeeDeadline < resultDate) {
      newErrors.enrollmentFeeDeadline = "入学金期限は発表日以降にしてください";
    }

    if (!tuitionDeadline) {
      newErrors.tuitionDeadline = "授業料期限を選択してください";
    } else if (enrollmentFeeDeadline && tuitionDeadline < enrollmentFeeDeadline) {
      newErrors.tuitionDeadline = "授業料期限は入学金期限以降にしてください";
    }

    const enrollmentFeeNum = parseInt(enrollmentFee);
    if (!enrollmentFee || isNaN(enrollmentFeeNum) || enrollmentFeeNum <= 0) {
      newErrors.enrollmentFee = "入学金は正の数で入力してください";
    }

    const tuitionNum = parseInt(tuition);
    if (!tuition || isNaN(tuitionNum) || tuitionNum <= 0) {
      newErrors.tuition = "授業料は正の数で入力してください";
    } else if (enrollmentFeeNum >= tuitionNum) {
      newErrors.tuition = "授業料は入学金より大きくしてください";
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    if (!validate()) return;

    const schoolData: SchoolWithState = {
      id: school?.id ?? nextId,
      name: name.trim(),
      priority,
      examDate: dateToDay(examDate!),
      resultDate: dateToDay(resultDate!),
      enrollmentFeeDeadline: dateToDay(enrollmentFeeDeadline!),
      tuitionDeadline: dateToDay(tuitionDeadline!),
      enrollmentFee: parseInt(enrollmentFee),
      tuition: parseInt(tuition),
      passStatus: school?.passStatus ?? "notYetAnnounced",
      enrollmentFeePaid: school?.enrollmentFeePaid ?? false,
      tuitionPaid: school?.tuitionPaid ?? false,
    };

    onSave(schoolData);
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>{isEditing ? "学校を編集" : "学校を追加"}</CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="space-y-4">
          {/* 大学名 */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              大学名 <span className="text-red-500">*</span>
            </label>
            <Input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="例: 東京大学"
            />
            {errors.name && (
              <p className="text-red-500 text-sm mt-1">{errors.name}</p>
            )}
          </div>

          {/* 志望順位 */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              志望順位 <span className="text-red-500">*</span>
            </label>
            <Input
              type="number"
              min="1"
              value={priority}
              onChange={(e) => setPriority(parseInt(e.target.value) || 1)}
            />
            {errors.priority && (
              <p className="text-red-500 text-sm mt-1">{errors.priority}</p>
            )}
          </div>

          {/* 日付フィールド */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <DatePicker
                label="受験日"
                value={examDate}
                onChange={setExamDate}
              />
              {errors.examDate && (
                <p className="text-red-500 text-sm mt-1">{errors.examDate}</p>
              )}
            </div>
            <div>
              <DatePicker
                label="発表日"
                value={resultDate}
                onChange={setResultDate}
              />
              {errors.resultDate && (
                <p className="text-red-500 text-sm mt-1">{errors.resultDate}</p>
              )}
            </div>
            <div>
              <DatePicker
                label="入学金期限"
                value={enrollmentFeeDeadline}
                onChange={setEnrollmentFeeDeadline}
              />
              {errors.enrollmentFeeDeadline && (
                <p className="text-red-500 text-sm mt-1">
                  {errors.enrollmentFeeDeadline}
                </p>
              )}
            </div>
            <div>
              <DatePicker
                label="授業料期限"
                value={tuitionDeadline}
                onChange={setTuitionDeadline}
              />
              {errors.tuitionDeadline && (
                <p className="text-red-500 text-sm mt-1">
                  {errors.tuitionDeadline}
                </p>
              )}
            </div>
          </div>

          {/* 金額フィールド */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                入学金（円） <span className="text-red-500">*</span>
              </label>
              <Input
                type="number"
                min="1"
                value={enrollmentFee}
                onChange={(e) => setEnrollmentFee(e.target.value)}
                placeholder="例: 200000"
              />
              {errors.enrollmentFee && (
                <p className="text-red-500 text-sm mt-1">
                  {errors.enrollmentFee}
                </p>
              )}
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                授業料（円） <span className="text-red-500">*</span>
              </label>
              <Input
                type="number"
                min="1"
                value={tuition}
                onChange={(e) => setTuition(e.target.value)}
                placeholder="例: 1200000"
              />
              {errors.tuition && (
                <p className="text-red-500 text-sm mt-1">{errors.tuition}</p>
              )}
            </div>
          </div>

          {/* ボタン */}
          <div className="flex justify-end gap-2 pt-4">
            <Button type="button" variant="outline" onClick={onCancel}>
              キャンセル
            </Button>
            <Button type="submit">{isEditing ? "更新" : "追加"}</Button>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
