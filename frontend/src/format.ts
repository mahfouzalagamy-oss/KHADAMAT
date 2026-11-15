const DAYS = ["الأحد", "الإثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"];
const MONTHS = ["يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو", "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"];

export const egp = (n?: number | null) => (n == null ? "—" : `${Math.round(n)} ج.م`);

export function phoneFmt(p?: string | null) {
  if (!p) return "";
  const d = p.replace("+20", "");
  return `\u2066+20 ${d.slice(0, 2)} ${d.slice(2, 6)} ${d.slice(6)}\u2069`;
}

export const dayName = (d: Date) => DAYS[d.getDay()];
export const monthName = (d: Date) => MONTHS[d.getMonth()];

export function timeFmt(d: Date) {
  const h = d.getHours();
  const m = d.getMinutes().toString().padStart(2, "0");
  return `${h % 12 === 0 ? 12 : h % 12}:${m} ${h < 12 ? "ص" : "م"}`;
}

export function dateTimeFmt(iso?: string | null) {
  if (!iso) return "";
  const d = new Date(iso);
  return `${dayName(d)} ${d.getDate()} ${monthName(d)} • ${timeFmt(d)}`;
}

export function timeAgo(iso: string) {
  const s = Math.max(0, (Date.now() - new Date(iso).getTime()) / 1000);
  if (s < 60) return "الآن";
  if (s < 3600) return `منذ ${Math.floor(s / 60)} د`;
  if (s < 86400) return `منذ ${Math.floor(s / 3600)} س`;
  return `منذ ${Math.floor(s / 86400)} يوم`;
}

export type Tone = "brand" | "success" | "warning" | "error" | "info" | "muted";

export const STATUS: Record<string, { label: string; tone: Tone; icon: string }> = {
  open: { label: "بانتظار العروض", tone: "warning", icon: "hourglass" },
  booked: { label: "تم الحجز", tone: "info", icon: "calendar" },
  on_the_way: { label: "الفني في الطريق", tone: "brand", icon: "car" },
  arrived: { label: "الفني وصل", tone: "brand", icon: "location" },
  in_progress: { label: "جاري العمل", tone: "brand", icon: "construct" },
  completed: { label: "تم الإنجاز", tone: "success", icon: "checkmark-circle" },
  cancelled: { label: "ملغي", tone: "error", icon: "close-circle" },
};

export const FLOW = ["booked", "on_the_way", "arrived", "in_progress", "completed"];

export const IDENTITY: Record<string, { label: string; tone: Tone }> = {
  none: { label: "غير موثق", tone: "muted" },
  pending: { label: "قيد المراجعة", tone: "warning" },
  approved: { label: "موثق", tone: "success" },
  rejected: { label: "مرفوض", tone: "error" },
};

export const ROLE_AR: Record<string, string> = {
  customer: "عميل",
  technician: "فني",
  company: "شركة",
  admin: "إدارة",
};