interface StatCardProps {
  title: string;
  value: string;
  subtitle?: string;
  icon?: React.ReactNode;
  color?: "gold" | "green" | "red" | "default";
}

const colorMap: Record<string, string> = {
  gold: "text-[#D4AF37]",
  green: "text-[#2ED573]",
  red: "text-[#FF4757]",
  default: "text-white",
};

export function StatCard({ title, value, subtitle, icon, color = "default" }: StatCardProps) {
  return (
    <div className="bg-[#1A1A2E] rounded-xl border border-white/10 p-5">
      <div className="flex items-center justify-between mb-3">
        <span className="text-sm text-[#A0A0B0]">{title}</span>
        {icon && <span className="text-[#A0A0B0]">{icon}</span>}
      </div>
      <div className={`text-2xl font-bold ${colorMap[color]}`}>{value}</div>
      {subtitle && <div className="text-xs text-[#A0A0B0] mt-1">{subtitle}</div>}
    </div>
  );
}
