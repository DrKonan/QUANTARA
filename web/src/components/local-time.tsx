"use client";

import { useEffect, useState } from "react";

interface LocalTimeProps {
  /** ISO 8601 date string (e.g. "2026-04-15T19:00:00+00:00") */
  date: string;
  /** "time" = HH:MM, "date" = DD/MM or DD MMM YYYY, "datetime" = both */
  format?: "time" | "date" | "date-long" | "datetime" | "full";
  className?: string;
}

/**
 * Renders a date/time converted to the user's local timezone.
 * Uses browser Intl on the client; shows a UTC fallback during SSR/hydration.
 */
export function LocalTime({ date, format = "time", className }: LocalTimeProps) {
  const [text, setText] = useState(() => formatFallback(date, format));

  useEffect(() => {
    setText(formatLocal(date, format));
  }, [date, format]);

  return <span className={className} suppressHydrationWarning>{text}</span>;
}

function formatLocal(iso: string, fmt: string): string {
  const d = new Date(iso);
  const locale = navigator.language || "fr-FR";

  switch (fmt) {
    case "time":
      return d.toLocaleTimeString(locale, { hour: "2-digit", minute: "2-digit" });
    case "date":
      return d.toLocaleDateString(locale, { day: "2-digit", month: "2-digit" });
    case "date-long":
      return d.toLocaleDateString(locale, { day: "2-digit", month: "short", year: "numeric" });
    case "datetime":
      return `${d.toLocaleDateString(locale, { day: "2-digit", month: "2-digit" })} ${d.toLocaleTimeString(locale, { hour: "2-digit", minute: "2-digit" })}`;
    case "full":
      return d.toLocaleDateString(locale, { weekday: "long", day: "numeric", month: "long", year: "numeric" });
    default:
      return d.toLocaleTimeString(locale, { hour: "2-digit", minute: "2-digit" });
  }
}

/** SSR fallback: format in UTC so the server doesn't use its own timezone */
function formatFallback(iso: string, fmt: string): string {
  const d = new Date(iso);
  const hh = String(d.getUTCHours()).padStart(2, "0");
  const mm = String(d.getUTCMinutes()).padStart(2, "0");
  const dd = String(d.getUTCDate()).padStart(2, "0");
  const mo = String(d.getUTCMonth() + 1).padStart(2, "0");
  const yyyy = d.getUTCFullYear();

  switch (fmt) {
    case "time":
      return `${hh}:${mm}`;
    case "date":
      return `${dd}/${mo}`;
    case "date-long":
      return `${dd}/${mo}/${yyyy}`;
    case "datetime":
      return `${dd}/${mo} ${hh}:${mm}`;
    case "full":
      return `${dd}/${mo}/${yyyy}`;
    default:
      return `${hh}:${mm}`;
  }
}
