interface StatCardProps {
  title: string;
  value: string;
  subtitle?: string;
  icon?: React.ReactNode;
  color?: "gold" | "green" | "red" | "default";
  trend?: string;
}

const colorMap: Record<string, { text: string; glow: string; iconBg: string }> = {
  gold: { text: "text-[#D4AF37]", glow: "glow-gold", iconBg: "bg-[#D4AF37]/10 text-[#D4AF37]" },
  green: { text: "text-[#34D399]", glow: "glow-green", iconBg: "bg-[#34D399]/10 text-[#34D399]" },
  red: { text: "text-[#F87171]", glow: "glow-red", iconBg: "bg-[#F87171]/10 text-[#F87171]" },
  default: { text: "text-white", glow: "", iconBg: "bg-white/5 text-[#9B9BB0]" },
};

export function StatCard({ title, value, subtitle, icon, color = "default", trend }: StatCardProps) {
  const c = colorMap[color];
  return (
    <div className={`glass-card p-5 animate-fade-up transition-all duration-300 ${c.glow}`}>
      <div className="flex items-start justify-between mb-3">
        <span className="text-xs font-medium uppercase tracking-wider text-[#6B6B80]">{title}</span>
        {icon && <span className={`p-2 rounded-lg ${c.iconBg}`}>{icon}</span>}
      </div>
      <div className={`text-2xl sm:text-3xl font-bold ${c.text}`}>{value}</div>
      <div className="flex items-center gap-2 mt-1.5">
        {subtitle && <span className="text-xs text-[#6B6B80]">{subtitle}</span>}
        {trend && <span className="text-xs text-[#34D399] font-medium">{trend}</span>}
      </div>
    </div>
  );
}
