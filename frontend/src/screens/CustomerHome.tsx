import { Pressable, RefreshControl, ScrollView, View } from "react-native";
import { useRouter } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { LinearGradient } from "expo-linear-gradient";
import Animated, { FadeInDown } from "react-native-reanimated";
import * as Haptics from "expo-haptics";
import { useApi } from "@/src/api";
import { useAuth } from "@/src/auth";
import { Card, ErrorView, Icon, IconBtn, IconName, Row, SectionTitle, Txt } from "@/src/ui";
import { useTheme } from "@/src/theme";
import { egp } from "@/src/format";
import { usesNativeTabs } from "@/src/navigation";
import { RequestCard } from "@/src/components/RequestCard";

export default function CustomerHome() {
  const { colors } = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const { user } = useAuth();
  const cat = useApi<any>("/catalog");
  const reqs = useApi<any[]>("/requests");
  const notes = useApi<any>("/notifications", 20000);
  const bottomChrome = usesNativeTabs ? insets.bottom : 0;
  const active = (reqs.data ?? []).filter((r) => !["completed", "cancelled"].includes(r.status)).slice(0, 2);

  return (
    <View style={{ flex: 1, backgroundColor: colors.surface }}>
      <View
        style={{
          paddingTop: insets.top + 8,
          paddingHorizontal: 16,
          paddingBottom: 12,
          backgroundColor: colors.surfaceSecondary,
          borderBottomWidth: 1,
          borderBottomColor: colors.border,
        }}
      >
        <Row style={{ justifyContent: "space-between" }}>
          <Row gap={8} style={{ flex: 1 }}>
            <View
              style={{
                width: 44,
                height: 44,
                borderRadius: 22,
                backgroundColor: colors.brand,
                alignItems: "center",
                justifyContent: "center",
              }}
            >
              <Icon name="location" size={22} color={colors.onBrand} />
            </View>
            <View style={{ flex: 1 }}>
              <Txt variant="caption" color={colors.muted}>
                موقعك
              </Txt>
              <Txt variant="title" testID="home-location-label">
                المنصورة، الدقهلية
              </Txt>
            </View>
          </Row>
          <IconBtn
            testID="home-notifications-button"
            icon="notifications"
            badge={notes.data?.unread}
            onPress={() => router.push("/notifications")}
          />
        </Row>
      </View>

      <ScrollView
        contentContainerStyle={{ padding: 16, gap: 24, paddingBottom: bottomChrome + 24 }}
        refreshControl={
          <RefreshControl
            refreshing={cat.isRefetching}
            onRefresh={() => {
              cat.refetch();
              reqs.refetch();
            }}
            tintColor={colors.brand}
          />
        }
      >
        <Txt variant="h1" testID="home-greeting">
          أهلاً {user?.name?.split(" ")[0]}، محتاج إيه النهارده؟
        </Txt>

        <Animated.View entering={FadeInDown}>
          <Pressable
            testID="home-ai-describe-card"
            onPress={() => {
              Haptics.selectionAsync().catch(() => {});
              router.push("/request/new");
            }}
          >
            <LinearGradient
              colors={[colors.brandDeep, colors.brand]}
              start={{ x: 1, y: 0 }}
              end={{ x: 0, y: 1 }}
              style={{ borderRadius: 24, padding: 20, gap: 12 }}
            >
              <Row gap={8}>
                <View style={{ backgroundColor: colors.brandSecondary, borderRadius: 999, paddingHorizontal: 12, paddingVertical: 2 }}>
                  <Txt variant="caption" weight="700" color={colors.onBrandSecondary}>
                    مساعد ذكي
                  </Txt>
                </View>
                <Icon name="sparkles" size={18} color={colors.brandSecondary} />
              </Row>
              <Txt variant="h2" color={colors.onBrand}>
                اوصف مشكلتك بكلامك، وإحنا نرتبها للفني
              </Txt>
              <Txt color={colors.brandTertiary}>نحدد نوع الخدمة ونقدّر السعر بالجنيه قبل ما تحجز</Txt>
              <Row gap={8}>
                <View
                  style={{
                    backgroundColor: colors.surfaceSecondary,
                    borderRadius: 999,
                    paddingHorizontal: 16,
                    height: 44,
                    flexDirection: "row-reverse",
                    alignItems: "center",
                    gap: 8,
                  }}
                >
                  <Txt weight="700" color={colors.brandDeep}>
                    ابدأ الوصف
                  </Txt>
                  <Icon name="arrow-back" size={18} color={colors.brandDeep} />
                </View>
              </Row>
            </LinearGradient>
          </Pressable>
        </Animated.View>

        {active.length ? (
          <View>
            <SectionTitle title="طلباتك الحالية" />
            <View style={{ gap: 12 }}>
              {active.map((r, i) => (
                <RequestCard key={r.id} r={r} index={i} />
              ))}
            </View>
          </View>
        ) : null}

        <View>
          <SectionTitle title="الخدمات" />
          {cat.isError ? (
            <ErrorView message={(cat.error as Error)?.message} onRetry={() => cat.refetch()} />
          ) : (
            <View style={{ flexDirection: "row-reverse", flexWrap: "wrap", gap: 12 }}>
              {(cat.data?.categories ?? Array.from({ length: 8 }, (_, i) => ({ id: `s${i}` }))).map((c: any, i: number) => (
                <Animated.View key={c.id} entering={FadeInDown.delay(i * 40)} style={{ width: "48%", flexGrow: 1 }}>
                  <Card
                    testID={`home-category-${c.id}`}
                    onPress={c.name ? () => router.push(`/category/${c.id}`) : undefined}
                    style={{ gap: 12, minHeight: 132, opacity: c.name ? 1 : 0.5 }}
                  >
                    <View
                      style={{
                        width: 52,
                        height: 52,
                        borderRadius: 16,
                        backgroundColor: i % 2 ? colors.brandSecondary : colors.brandPrimary,
                        alignItems: "center",
                        justifyContent: "center",
                        alignSelf: "flex-end",
                      }}
                    >
                      {c.icon ? (
                        <Icon name={c.icon as IconName} size={26} color={i % 2 ? colors.onBrandSecondary : colors.onBrandPrimary} />
                      ) : null}
                    </View>
                    <View>
                      <Txt variant="title">{c.name ?? " "}</Txt>
                      {c.price_from ? (
                        <Txt variant="caption" color={colors.muted}>
                          يبدأ من {egp(c.price_from)}
                        </Txt>
                      ) : null}
                    </View>
                  </Card>
                </Animated.View>
              ))}
            </View>
          )}
        </View>

        <Card style={{ backgroundColor: colors.surfaceTertiary, borderColor: colors.brandTertiary, gap: 12 }}>
          {(
            [
              ["shield-checkmark", "فنيين موثقين بالبطاقة", "كل فني بيتراجع من الإدارة قبل ما يشتغل"],
              ["pricetags", "قارن العروض بنفسك", "شوف السعر والتقييم ووقت الوصول واختار"],
              ["cash", "ادفع كاش بعد الشغل", "بدون تخزين أي بيانات بطاقات بنكية"],
            ] as const
          ).map(([icon, t, s]) => (
            <Row key={t} gap={12}>
              <Icon name={icon} size={24} color={colors.brand} />
              <View style={{ flex: 1 }}>
                <Txt weight="700" color={colors.onSurfaceTertiary}>
                  {t}
                </Txt>
                <Txt variant="caption" color={colors.muted}>
                  {s}
                </Txt>
              </View>
            </Row>
          ))}
        </Card>
      </ScrollView>
    </View>
  );
}