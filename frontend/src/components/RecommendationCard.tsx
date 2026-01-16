import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { UrgencyBadge } from "@/components/StatusBadges";
import type { GetRecommendationResult, SchoolWithState } from "@/types";

interface RecommendationCardProps {
  result: GetRecommendationResult;
  schools: SchoolWithState[];
}

export function RecommendationCard({
  result,
  schools,
}: RecommendationCardProps) {
  const { action, reason, urgency, allRecommendations } = result;

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
        return `${getSchoolName(schoolId)}の入学金を支払ってください`;
      case "payTuition":
        return `${getSchoolName(schoolId)}の授業料を支払ってください`;
      case "doNothing":
        return "現在、支払いの必要はありません";
      default:
        return "不明なアクション";
    }
  };

  const isDoNothing = action.type === "doNothing";

  return (
    <div className="space-y-4">
      {/* メイン推奨 */}
      <Card
        className={
          urgency === 0
            ? "border-red-300 bg-red-50"
            : urgency <= 3
            ? "border-yellow-300 bg-yellow-50"
            : ""
        }
      >
        <CardHeader className="pb-2">
          <div className="flex items-center justify-between">
            <CardTitle className="text-lg">推奨アクション</CardTitle>
            {!isDoNothing && <UrgencyBadge urgency={urgency} />}
          </div>
        </CardHeader>
        <CardContent>
          <p className="text-lg font-medium mb-2">
            {getActionDescription(action.type, action.schoolId)}
          </p>
          {!isDoNothing && action.schoolId !== undefined && (
            <p className="text-gray-600 mb-2">
              金額: {formatAmount(action.schoolId, action.type)}
            </p>
          )}
          <p className="text-gray-600">
            <span className="font-medium">理由:</span> {reason}
          </p>
        </CardContent>
      </Card>

      {/* その他の推奨 */}
      {allRecommendations.length > 1 && (
        <div>
          <h4 className="text-sm font-medium text-gray-600 mb-2">
            その他の推奨:
          </h4>
          <div className="space-y-2">
            {allRecommendations.slice(1).map((rec, index) => (
              <Card key={index} className="bg-gray-50">
                <CardContent className="py-3">
                  <div className="flex items-center justify-between">
                    <p className="text-sm">
                      {getActionDescription(rec.action.type, rec.action.schoolId)}
                    </p>
                    <UrgencyBadge urgency={rec.urgency} />
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
