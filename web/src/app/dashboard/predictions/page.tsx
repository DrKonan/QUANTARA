import { createSupabaseAdminClient } from "@/lib/supabase/server";

export const revalidate = 30;

interface Prediction {
  id: number;
  prediction: string;
  prediction_type: string;
  confidence: number;
  confidence_label: string;
  is_correct: boolean | null;
  is_live: boolean;
  is_published: boolean;
  created_at: string;
  matches: { home_team: string; away_team: string; league: string; match_date: string } | null;
}

export default async function PredictionsPage() {
  const supabase = await createSupabaseAdminClient();

  const { data: predictions } = await supabase
    .from("predictions")
    .select("id, prediction, prediction_type, confidence, confidence_label, is_correct, is_live, is_published, created_at, matches(home_team, away_team, league, match_date)")
    .order("created_at", { ascending: false })
    .limit(100);

  const list = (predictions ?? []) as unknown as Prediction[];

  return (
    <div className="p-4 sm:p-6 lg:p-8">
      <div className="mb-6 lg:mb-8">
        <h2 className="text-xl sm:text-2xl font-bold">Pronos</h2>
        <p className="text-[#A0A0B0] mt-1 text-sm sm:text-base">
          {list.length} pronos affichés (100 derniers)
        </p>
      </div>

      <div className="bg-[#1A1A2E] rounded-xl border border-white/10 overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-white/5 text-[#A0A0B0]">
              <th className="text-left p-4 font-medium">Match</th>
              <th className="text-left p-4 font-medium">Ligue</th>
              <th className="text-left p-4 font-medium">Événement</th>
              <th className="text-left p-4 font-medium">Type</th>
              <th className="text-right p-4 font-medium">Confiance</th>
              <th className="text-right p-4 font-medium">Live</th>
              <th className="text-right p-4 font-medium">Résultat</th>
              <th className="text-right p-4 font-medium">Date</th>
            </tr>
          </thead>
          <tbody>
            {list.map((pred) => (
              <tr key={pred.id} className="border-b border-white/5 hover:bg-white/5">
                <td className="p-4 font-medium whitespace-nowrap">
                  {pred.matches?.home_team} vs {pred.matches?.away_team}
                </td>
                <td className="p-4 text-[#A0A0B0]">{pred.matches?.league}</td>
                <td className="p-4">{pred.prediction}</td>
                <td className="p-4 text-[#A0A0B0]">{pred.prediction_type}</td>
                <td className="p-4 text-right">
                  <span className={`px-2 py-0.5 rounded text-xs font-medium ${confidenceColor(pred.confidence_label)}`}>
                    {(pred.confidence * 100).toFixed(0)}%
                  </span>
                </td>
                <td className="p-4 text-right">
                  {pred.is_live && <span className="text-xs text-red-400 font-medium">🔴 Live</span>}
                </td>
                <td className="p-4 text-right">
                  {pred.is_correct === null
                    ? <span className="text-[#A0A0B0] text-xs">—</span>
                    : pred.is_correct
                    ? <span className="text-[#2ED573] text-xs font-medium">✅</span>
                    : <span className="text-[#FF4757] text-xs font-medium">❌</span>
                  }
                </td>
                <td className="p-4 text-right text-[#A0A0B0] text-xs whitespace-nowrap">
                  {new Date(pred.created_at).toLocaleDateString("fr")}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function confidenceColor(label: string): string {
  const m: Record<string, string> = {
    excellence: "text-[#D4AF37] bg-[#D4AF37]/10",
    high: "text-[#2ED573] bg-[#2ED573]/10",
    elevated: "text-[#1E90FF] bg-[#1E90FF]/10",
  };
  return m[label] ?? "text-white bg-white/10";
}
