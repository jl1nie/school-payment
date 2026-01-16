import { Badge } from "@/components/ui/badge";
import type { PassStatus } from "@/types";

interface PassStatusBadgeProps {
  status: PassStatus;
  className?: string;
}

export function PassStatusBadge({ status, className }: PassStatusBadgeProps) {
  const config = {
    notYetAnnounced: {
      label: "未発表",
      variant: "secondary" as const,
      icon: "🔘",
    },
    passed: {
      label: "合格",
      variant: "success" as const,
      icon: "✅",
    },
    failed: {
      label: "不合格",
      variant: "destructive" as const,
      icon: "❌",
    },
    cancelled: {
      label: "取消",
      variant: "destructive" as const,
      icon: "⛔",
    },
  };

  const { label, variant, icon } = config[status];

  return (
    <Badge variant={variant} className={className}>
      {icon} {label}
    </Badge>
  );
}

interface PaymentStatusBadgeProps {
  enrollmentFeePaid: boolean;
  tuitionPaid: boolean;
  className?: string;
}

export function PaymentStatusBadge({
  enrollmentFeePaid,
  tuitionPaid,
  className,
}: PaymentStatusBadgeProps) {
  if (tuitionPaid) {
    return (
      <Badge variant="success" className={className}>
        💰 全額支払済
      </Badge>
    );
  }
  if (enrollmentFeePaid) {
    return (
      <Badge variant="warning" className={className}>
        💰 入学金のみ
      </Badge>
    );
  }
  return (
    <Badge variant="secondary" className={className}>
      💰 未払い
    </Badge>
  );
}

interface UrgencyBadgeProps {
  urgency: number;
  className?: string;
}

export function UrgencyBadge({ urgency, className }: UrgencyBadgeProps) {
  if (urgency === 0) {
    return (
      <Badge variant="destructive" className={className}>
        🔴 本日期限！
      </Badge>
    );
  }
  if (urgency <= 3) {
    return (
      <Badge variant="warning" className={className}>
        🟡 残り{urgency}日
      </Badge>
    );
  }
  if (urgency <= 7) {
    return (
      <Badge variant="default" className={className}>
        🔵 残り{urgency}日
      </Badge>
    );
  }
  return (
    <Badge variant="secondary" className={className}>
      残り{urgency}日
    </Badge>
  );
}
