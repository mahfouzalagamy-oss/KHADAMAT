import { useState } from "react";
import { RefreshControl, ScrollView, Switch, View } from "react-native";
import { useRouter } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import * as Haptics from "expo-haptics";
import { api, useApi } from "@/src/api";
import { Badge, Btn, Card, Empty, ErrorView, Icon, IconBtn, IconName, Loading, Row, SectionTitle, Txt, useToast } from "@/src/ui";
import { useTheme } from "@/src/theme";
import { usesNativeTabs } from "@/src/navigation";
import { dateTimeFmt, egp, IDENTITY } from "@/src/format";
import { RequestCard } from "@/src/components/RequestCard";

export default function TechHome() {
  const { colors } = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const toast = useToast();
  const q = useApi<any>("/tech/dashboard", 15000);
  const notes = useApi<any>("/notifications", 20000);
  const [toggling, setToggling] = useState(false);
  const bottomChrome = usesNativeTabs ? insets.bottom : 0;
  const p = q.data?.profile;

  const toggleOnline = async (v: boolean) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium).catch(() => {});
    setToggling(true);
    try {
      await api("/tech/profile", { method: "PUT", body: { categories: p.categories, bio: p.bio, online: v } });
      await q.refetch();
    } catch (e: any) {
      toast(e.message, "error");
    } finally {
      setToggling(false);
    }
  };

  return (
    <View style={{ flex: 1, backgroundColor: colors.surface }}>
      <View style={{ paddingTop: insets.top + 8, paddingHorizontal: 16, paddingBottom: 12, backgroundColor: colors.brandDeep }}>
        <Row style={{ justifyContent: "space-between" }}>
          <View style={{ flex: 1 }}>
            <Txt variant="caption" color={colors.brandTertiary}>
              لوحة الفني
            </Txt>
            <Txt variant="h2" color={colors.onBrand}>
              {p?.name ?? ""}
            </Txt>
          </View>
          <Row gap={8}>
            <View style={{ alignItems: "center" }}>
              <Switch
                testID="tech-online-toggle"
                value={!!p?.online}
                disabled={!p || toggling}
                onValueChange={toggleOnline}
                trackColor={{ true: colors.brandSecondary, false: colors.borderStrong }}
                thumbColor={colors.surfaceSecondary}
              />
              <Txt variant="caption" color={colors.onBrand}>
                {p?.online ? "متاح" : "غير متاح"}
              </Txt>
            </View>
            <IconBtn testID="tech-notifications-button" icon="notifications" badge={notes.data?.unread} onPress={() => router.push("/notifications")} />
          </Row>
        </Row>
      </View>
      {q.isLoading ? (
        <Loading />
      ) : q.isError ? (
        <ErrorView message={(q.error as Error).message} onRetry={() => q.refetch()} />
      ) : (
        <ScrollView
          contentContainerStyle={{ padding: 16, gap: 16, paddingBottom: bottomChrome + 24 }}
          refreshControl={<RefreshControl refreshing={q.isRefetching} onRefresh={() => q.refetch()} tintColor={colors.brand} />}
        >
          {p.identity_status !== "approved" || !q.data.subscription_active || !p.categories.length ? (
            <Card testID="tech-setup-card" onPress={() => router.push("/tech/profile")} style={{ gap: 8, backgroundColor: colors.warningSoft, borderColor: colors.warning }}>
              <Row gap={8}>
                <Icon name="alert-circle" size={22} color={colors.onWarningSoft} />
                <Txt variant="title" color={colors.onWarningSoft} style={{ flex: 1 }}>
                  كمّل ملفك عشان تقدر تقدم عروض
                </Txt>
                <Icon name="chevron-back" size={20} color={colors.onWarningSoft} />
              </Row>
              <Row gap={8} style={{ flexWrap: "wrap" }}>
                <Badge label={`الهوية: ${IDENTITY[p.identity_status].label}`} tone={IDENTITY[p.identity_status].tone} />
                <Badge label={q.data.subscription_active ? "الاشتراك مفعل" : "الاشتراك غير مفعل"} tone={q.data.subscription_active ? "success" : "error"} />
                {!p.categories.length ? <Badge label="اختار تخصصاتك" tone="info" /> : null}
              </Row>
            </Card>
          ) : null}

          <Row gap={12}>
            {(
              [
                ["cash", "الأرباح", egp(p.earnings), "tech-metric-earnings"],
                ["checkmark-done", "شغلانات", String(p.jobs_done), "tech-metric-jobs"],
                ["star", "التقييم", p.rating ? p.rating.toFixed(1) : "—", "tech-metric-rating"],
              ] as const
            ).map(([icon, label, value, tid], i) => (
              <Card key={label} testID={tid} style={{ flex: 1, gap: 4, backgroundColor: i === 0 ? colors.brand : colors.surfaceSecondary, borderColor: i === 0 ? colors.brand : colors.border, padding: 12 }}>
                <Icon name={icon as IconName} size={20} color={i === 0 ? colors.brandSecondary : colors.brand} />
                <Txt variant="title" color={i === 0 ? colors.onBrand : colors.onSurface} numberOfLines={1} adjustsFontSizeToFit>
                  {value}
                </Txt>
                <Txt variant="caption" color={i === 0 ? colors.brandTertiary : colors.muted}>
                  {label}
                </Txt>
              </Card>
            ))}
          </Row>

          {q.data.active_jobs.length ? (
            <View style={{ gap: 12 }}>
              <SectionTitle title="شغلك الجاي" />
              {q.data.active_jobs.map((r: any, i: number) => (
                <RequestCard key={r.id} r={r} index={i} />
              ))}
            </View>
          ) : null}

          <View style={{ gap: 12 }}>
            <SectionTitle title="طلبات جديدة في تخصصك" action={<Badge label={`${q.data.open_requests.length}`} tone="info" />} />
            {!q.data.open_requests.length ? (
              <Empty testID="tech-requests-empty" icon="cafe" title="مفيش طلبات جديدة دلوقتي" body="خليك متاح وهنبلغك أول ما ييجي طلب" />
            ) : (
              q.data.open_requests.map((r: any) => (
                <Card key={r.id} testID={`tech-open-request-${r.id}`} style={{ gap: 8 }}>
                  <Row style={{ justifyContent: "space-between" }}>
                    <Txt variant="title" style={{ flex: 1 }} numberOfLines={1}>
                      {r.category_name} • {r.service_name}
                    </Txt>
                    {r.urgency === "urgent" ? <Badge label="عاجل" tone="error" icon="flash" /> : null}
                  </Row>
                  <Txt variant="caption" color={colors.onSurfaceSecondary} numberOfLines={2}>
                    {r.description}
                  </Txt>
                  <Row gap={12}>
                    <Row gap={4}>
                      <Icon name="location" size={14} color={colors.brand} />
                      <Txt variant="caption">{r.area}</Txt>
                    </Row>
                    <Row gap={4}>
                      <Icon name="calendar" size={14} color={colors.brand} />
                      <Txt variant="caption">{dateTimeFmt(r.scheduled_at)}</Txt>
                    </Row>
                  </Row>
                  <Btn
                    testID={`tech-open-request-offer-${r.id}`}
                    small
                    variant={r.already_offered ? "outline" : "primary"}
                    icon={r.already_offered ? "checkmark" : "pricetag"}
                    label={r.already_offered ? "قدمت عرض — عرض التفاصيل" : "قدّم عرض"}
                    onPress={() => router.push(`/request/${r.id}`)}
                  />
                </Card>
              ))
            )}
          </View>
        </ScrollView>
      )}
    </View>
  );
}