import { SchoolCard } from "@/components/SchoolCard";
import type { SchoolWithState, PassStatus } from "@/types";

interface SchoolListProps {
  schools: SchoolWithState[];
  baseYear?: number;
  onUpdatePassStatus: (id: number, status: PassStatus) => void;
  onUpdatePaymentStatus: (
    id: number,
    updates: { enrollmentFeePaid?: boolean; tuitionPaid?: boolean }
  ) => void;
  onEdit: (school: SchoolWithState) => void;
  onDelete: (id: number) => void;
}

export function SchoolList({
  schools,
  baseYear,
  onUpdatePassStatus,
  onUpdatePaymentStatus,
  onEdit,
  onDelete,
}: SchoolListProps) {
  if (schools.length === 0) {
    return (
      <div className="text-center py-12 text-gray-500">
        <p className="text-lg">まだ学校が追加されていません</p>
        <p className="text-sm mt-2">
          「学校を追加」ボタンをクリックして、志望校を追加してください
        </p>
      </div>
    );
  }

  // 志望順位でソート
  const sortedSchools = [...schools].sort((a, b) => a.priority - b.priority);

  return (
    <div className="grid gap-4 md:grid-cols-2">
      {sortedSchools.map((school, index) => (
        <SchoolCard
          key={school.id}
          school={school}
          colorIndex={index}
          baseYear={baseYear}
          onUpdatePassStatus={onUpdatePassStatus}
          onUpdatePaymentStatus={onUpdatePaymentStatus}
          onEdit={onEdit}
          onDelete={onDelete}
        />
      ))}
    </div>
  );
}
