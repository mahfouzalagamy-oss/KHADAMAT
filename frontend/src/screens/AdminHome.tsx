import { useState } from "react";
import { RefreshControl, ScrollView, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { useQueryClient } from "@tanstack/react-query";
import { api, useApi } from "@/src/api";
import { useAuth } from "@/src/auth";
import { Badge, Btn, Card, Chip, ChipRow, Empty, ErrorView, Icon, IconName, Loading, Row, Txt, useToast } from "@/src/ui";
import { useTheme } from "@/src/theme";
import { usesNativeTabs } from "@/src/navigation";
import { dateTimeFmt, egp, IDENTITY, phoneFmt } from "@/src/format";

const TABS = [
  { id: "overview", label: "نظرة عامة" },
  { id: "identity", label: "مراجعة الهوية" },
  { id: "invoices", label: "الاشتراكات" },
  { id: "techs", label: "الفنيين" },
];

export default function AdminHome() {
  const { colors } = useTheme();
  const insets = useSafeAreaInsets();
  const toast = useToast();
  const qc = useQueryClient();
  const { user } = useAuth();
  const [tab, setTab] = useState("overview");
  const [busy, setBusy] = useState<string | null>(null);
  const stats = useApi<any>("/admin/stats");
  const pending = useApi<any[]>("/admin/technicians?status=pending");
  const invoices = useApi<any[]>("/admin/invoices");
  const techs = useApi<any[]>(tab === "techs" ? "/admin/technicians" : null);
  const bottomChrome = usesNativeTabs ? insets.bottom : 0;

  const act = async (key: string, path: string, body: any, ok: string) => {
    setBusy(key);
    try {
      await api(path, { body });
      toast(ok);
      qc.invalidateQueries();
    } catch (e: any) {
      toast(e.message, "error");
    } finally {
      setBusy(null);
    }
  };

  const s = stats.data;
  return (
    <View style={{ flex: 1, backgroundColor: colors.surface }}>
      <View style={{ paddingTop: insets.top + 8, backgroundColor: colors.surfaceSecondary, borderBottomWidth: 1, borderBottomColor: colors.border }}>
        <View style={{ paddingHorizontal: 16 }}>
          <Txt variant="caption" color={colors.muted}>
            لوحة الإدارة • {user?.name}
          </Txt>
          <Txt variant="h1">خدمات — المنصورة</Txt>
        </View>
        <ChipRow testID="admin-tabs-row">
          {TABS.map((t) => (
            <Chip
              key={t.id}
              testID={`admin-tab-${t.id}`}
              label={t.id === "identity" && pending.data?.length ? `${t.label} (${pending.data.length})` : t.label}
              selected={tab === t.id}
              onPress={() => setTab(t.id)}
            />
          ))}
        </ChipRow>
      </View>
      <ScrollView
        contentContainerStyle={{ padding: 16, gap: 12, paddingBottom: bottomChrome + 24 }}
        refreshControl={<RefreshControl refreshing={stats.isRefetching} onRefresh={() => qc.invalidateQueries()} tintColor={colors.brand} />}
      >
        {tab === "overview" ? (
          stats.isLoading ? (
            <Loading />
          ) : stats.isError ? (
            <ErrorView message={(stats.error as Error).message} onRetry={() => stats.refetch()} />
          ) : (
            <View style={{ flexDirection: "row-reverse", flexWrap: "wrap", gap: 12 }}>
              {(
                [
                  ["people", "العملاء", s.customers],
                  ["construct", "الفنيين", s.technicians],
                  ["id-card", "توثيق معلق", s.pending_reviews],
                  ["document-text", "كل الطلبات", s.requests],
                  ["hourglass", "طلبات مفتوحة", s.open_requests],
                  ["checkmark-done", "طلبات منجزة", s.completed],
                  ["cash", "قيمة الطلبات (كاش)", egp(s.gmv)],
                  ["card", "إيراد الاشتراكات", egp(s.subscription_revenue)],
                  ["receipt", "فواتير غير مدفوعة", s.unpaid_invoices],
                ] as const
              ).map(([icon, label, value], i) => (
                <Card key={label} testID={`admin-stat-${i}`} style={{ width: "47%", flexGrow: 1, gap: 4 }}>
                  <Icon name={icon as IconName} size={22} color={i % 2 ? colors.brandSecondary : colors.brand} />
                  <Txt variant="h2">{String(value)}</Txt>
                  <Txt variant="caption" color={colors.muted}>
                    {label}
                  </Txt>
                </Card>
              ))}
            </View>
          )
        ) : null}

        {tab === "identity" ? (
          !pending.data?.length ? (
            <Empty testID="admin-identity-empty" icon="shield-checkmark" title="مفيش طلبات توثيق معلقة" />
          ) : (
            pending.data.map((t) => (
              <Card key={t.user_id} testID={`admin-identity-${t.user_id}`} style={{ gap: 8 }}>
                <Row style={{ justifyContent: "space-between" }}>
                  <Txt variant="title">{t.name}</Txt>
                  <Badge label="قيد المراجعة" tone="warning" />
                </Row>
                <Txt variant="caption" color={colors.muted}>
                  {phoneFmt(t.phone)} • قدّم {dateTimeFmt(t.identity_submitted_at)}
                </Txt>
                <Card style={{ backgroundColor: colors.surfaceTertiary, borderColor: colors.brandTertiary, gap: 4, padding: 12 }}>
                  <Txt variant="caption" color={colors.muted}>
                    الاسم في البطاقة
                  </Txt>
                  <Txt weight="700">{t.identity_name}</Txt>
                  <Txt variant="caption" color={colors.muted}>
                    الرقم القومي
                  </Txt>
                  {t.id_front_url || t.id_back_url ? <Txt variant="caption" color={colors.brand}>مرفقات الهوية: {t.id_front_url ? "الوجه الأمامي ✓ " : ""}{t.id_back_url ? "الوجه الخلفي ✓" : ""}</Txt> : null}`n                  <Txt weight="700" testID={`admin-identity-nid-${t.user_id}`}>
                    {t.national_id}
                  </Txt>
                </Card>
                <Row gap={8}>
                  <Btn
                    testID={`admin-identity-approve-${t.user_id}`}
                    small
                    icon="checkmark-circle"
                    label="توثيق"
                    loading={busy === `a-${t.user_id}`}
                    style={{ flex: 1 }}
                    onPress={() => act(`a-${t.user_id}`, `/admin/technicians/${t.user_id}/identity`, { decision: "approve" }, "تم توثيق الفني")}
                  />
                  <Btn
                    testID={`admin-identity-reject-${t.user_id}`}
                    small
                    variant="danger"
                    icon="close-circle"
                    label="رفض"
                    loading={busy === `r-${t.user_id}`}
                    onPress={() =>
                      act(`r-${t.user_id}`, `/admin/technicians/${t.user_id}/identity`, { decision: "reject", note: "البيانات غير مطابقة" }, "تم رفض الطلب")
                    }
                  />
                </Row>
              </Card>
            ))
          )
        ) : null}

        {tab === "invoices" ? (
          !invoices.data?.length ? (
            <Empty testID="admin-invoices-empty" icon="receipt" title="مفيش فواتير اشتراك" />
          ) : (
            invoices.data.map((inv) => (
              <Card key={inv.id} testID={`admin-invoice-${inv.id}`} style={{ gap: 8 }}>
                <Row style={{ justifyContent: "space-between" }}>
                  <Txt variant="title">{inv.number}</Txt>
                  <Badge label={inv.status === "paid" ? "مدفوعة" : "غير مدفوعة"} tone={inv.status === "paid" ? "success" : "warning"} />
                </Row>
                <Row style={{ justifyContent: "space-between" }}>
                  <Txt color={colors.onSurfaceSecondary}>
                    {inv.technician_name} • اشتراك {inv.plan_name}
                  </Txt>
                  <Txt variant="title" color={colors.brand}>
                    {egp(inv.amount)}
                  </Txt>
                </Row>
                <Txt variant="caption" color={colors.muted}>
                  {dateTimeFmt(inv.created_at)}
                  {inv.paid_at ? ` • دُفعت ${dateTimeFmt(inv.paid_at)}` : ""}
                </Txt>
                {inv.status !== "paid" ? (
                  <Btn
                    testID={`admin-invoice-mark-paid-${inv.id}`}
                    small
                    icon="cash"
                    label="تأكيد استلام المبلغ نقدًا"
                    loading={busy === inv.id}
                    onPress={() => act(inv.id, `/admin/invoices/${inv.id}/mark-paid`, {}, "تم تفعيل اشتراك الفني")}
                  />
                ) : null}
              </Card>
            ))
          )
        ) : null}

        {tab === "techs" ? (
          techs.isLoading ? (
            <Loading />
          ) : (
            (techs.data ?? []).map((t) => (
              <Card key={t.user_id} testID={`admin-tech-${t.user_id}`} style={{ gap: 4 }}>
                <Row style={{ justifyContent: "space-between" }}>
                  <Txt variant="title">{t.name}</Txt>
                  <Badge label={IDENTITY[t.identity_status]?.label} tone={IDENTITY[t.identity_status]?.tone} />
                </Row>
                <Txt variant="caption" color={colors.muted}>
                  {phoneFmt(t.phone)} • {t.jobs_done} شغلانة • تقييم {t.rating || "—"}
                </Txt>
                <Txt variant="caption" color={t.subscription_until && t.subscription_until > new Date().toISOString() ? colors.brand : colors.error}>
                  {t.subscription_until && t.subscription_until > new Date().toISOString()
                    ? `اشتراك ساري حتى ${t.subscription_until.slice(0, 10)}`
                    : "بدون اشتراك ساري"}
                </Txt>
              </Card>
            ))
          )
        ) : null}
      </ScrollView>
    </View>
  );
}