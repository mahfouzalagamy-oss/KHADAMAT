import { useState } from "react";
import { Pressable, ScrollView, View } from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import Animated, { FadeInDown } from "react-native-reanimated";
import { useApi } from "@/src/api";
import { Btn, ErrorView, Header, Icon, Loading, Row, Txt } from "@/src/ui";
import { useTheme } from "@/src/theme";
import { egp } from "@/src/format";

export default function CategoryScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { colors } = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const q = useApi<any>(`/catalog/${id}`);
  const [selected, setSelected] = useState<string | null>(null);

  return (
    <View style={{ flex: 1, backgroundColor: colors.surface }}>
      <Header title={q.data?.name ?? "الخدمات"} subtitle="اختار الخدمة المناسبة" />
      {q.isLoading ? (
        <Loading />
      ) : q.isError ? (
        <ErrorView message={(q.error as Error).message} onRetry={() => q.refetch()} />
      ) : (
        <ScrollView contentContainerStyle={{ padding: 16, gap: 12, paddingBottom: 140 + insets.bottom }}>
          {q.data.services.map((s: any, i: number) => {
            const sel = selected === s.id;
            return (
              <Animated.View key={s.id} entering={FadeInDown.delay(i * 50)}>
                <Pressable
                  testID={`service-option-${s.id}`}
                  onPress={() => setSelected(s.id)}
                  style={({ pressed }) => ({
                    minHeight: 76,
                    padding: 16,
                    borderRadius: 20,
                    borderWidth: 2,
                    borderColor: sel ? colors.brand : colors.border,
                    backgroundColor: sel ? colors.surfaceTertiary : colors.surfaceSecondary,
                    flexDirection: "row-reverse",
                    alignItems: "center",
                    gap: 12,
                    transform: [{ scale: pressed ? 0.98 : 1 }],
                  })}
                >
                  <Icon name={sel ? "radio-button-on" : "radio-button-off"} size={24} color={sel ? colors.brand : colors.borderStrong} />
                  <View style={{ flex: 1 }}>
                    <Txt variant="title">{s.name}</Txt>
                    <Txt variant="caption" color={colors.muted}>
                      حوالي {s.duration_minutes} دقيقة
                    </Txt>
                  </View>
                  <View style={{ alignItems: "flex-start" }}>
                    <Txt variant="caption" color={colors.muted}>
                      من
                    </Txt>
                    <Txt variant="title" color={colors.brand}>
                      {egp(s.price_min)}
                    </Txt>
                  </View>
                </Pressable>
              </Animated.View>
            );
          })}
          <Pressable
            testID="service-option-custom"
            onPress={() => setSelected("custom")}
            style={{
              padding: 16,
              borderRadius: 20,
              borderWidth: 2,
              borderStyle: "dashed",
              borderColor: selected === "custom" ? colors.brand : colors.borderStrong,
              flexDirection: "row-reverse",
              alignItems: "center",
              gap: 12,
            }}
          >
            <Icon name="sparkles" size={24} color={colors.brand} />
            <View style={{ flex: 1 }}>
              <Txt variant="title">مشكلة تانية؟</Txt>
              <Txt variant="caption" color={colors.muted}>
                اوصفها بكلامك والمساعد الذكي يساعدك
              </Txt>
            </View>
          </Pressable>
          <Txt variant="caption" color={colors.muted}>
            الأسعار تقديرية، والسعر النهائي بيتحدد من عروض الفنيين اللي هتقارن بينها.
          </Txt>
        </ScrollView>
      )}
      <View
        style={{
          position: "absolute",
          bottom: 0,
          left: 0,
          right: 0,
          padding: 16,
          paddingBottom: insets.bottom + 16,
          backgroundColor: colors.surfaceSecondary,
          borderTopWidth: 1,
          borderTopColor: colors.border,
        }}
      >
        <Row>
          <Btn
            testID="category-continue-button"
            label="المتابعة للحجز"
            icon="arrow-back"
            disabled={!selected}
            style={{ flex: 1 }}
            onPress={() =>
              router.push({
                pathname: "/request/new",
                params: { category: id, service: selected === "custom" ? "" : selected ?? "" },
              })
            }
          />
        </Row>
      </View>
    </View>
  );
}