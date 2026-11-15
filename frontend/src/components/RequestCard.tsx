import { View } from "react-native";
import { useRouter } from "expo-router";
import Animated, { FadeInDown } from "react-native-reanimated";
import { Badge, Card, Icon, Row, Txt } from "@/src/ui";
import { useTheme } from "@/src/theme";
import { dateTimeFmt, egp, STATUS } from "@/src/format";

export function RequestCard({ r, index = 0 }: { r: any; index?: number }) {
  const { colors } = useTheme();
  const router = useRouter();
  const st = STATUS[r.status] ?? STATUS.open;
  return (
    <Animated.View entering={FadeInDown.delay(Math.min(index, 6) * 50)}>
      <Card testID={`request-card-${r.id}`} onPress={() => router.push(`/request/${r.id}`)} style={{ gap: 8 }}>
        <Row style={{ justifyContent: "space-between" }}>
          <Row gap={8} style={{ flex: 1 }}>
            <View
              style={{
                width: 40,
                height: 40,
                borderRadius: 12,
                backgroundColor: colors.brandTertiary,
                alignItems: "center",
                justifyContent: "center",
              }}
            >
              <Icon name="construct" size={20} color={colors.brand} />
            </View>
            <View style={{ flex: 1 }}>
              <Txt variant="title" numberOfLines={1}>
                {r.category_name} • {r.service_name}
              </Txt>
              <Txt variant="caption" color={colors.muted} numberOfLines={1}>
                {r.area} • {dateTimeFmt(r.scheduled_at)}
              </Txt>
            </View>
          </Row>
          <Badge label={st.label} tone={st.tone} />
        </Row>
        <Row style={{ justifyContent: "space-between" }}>
          {r.status === "open" ? (
            <Txt variant="caption" weight="700" color={colors.brand}>
              {r.offers_count ? `${r.offers_count} عروض متاحة للمقارنة` : "بانتظار عروض الفنيين"}
            </Txt>
          ) : (
            <Txt variant="caption" color={colors.muted}>
              {r.technician_name ?? ""}
            </Txt>
          )}
          {r.price ? (
            <Txt variant="title" color={colors.brand}>
              {egp(r.price)}
            </Txt>
          ) : null}
        </Row>
      </Card>
    </Animated.View>
  );
}