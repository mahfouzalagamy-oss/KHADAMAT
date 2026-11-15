import { useEffect } from "react";
import { FlatList, View } from "react-native";
import { useRouter } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { useQueryClient } from "@tanstack/react-query";
import { api, useApi } from "@/src/api";
import { Card, Empty, Header, Icon, Loading, Row, Txt } from "@/src/ui";
import { useTheme } from "@/src/theme";
import { timeAgo } from "@/src/format";

export default function Notifications() {
  const { colors } = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const qc = useQueryClient();
  const q = useApi<any>("/notifications");

  useEffect(() => {
    if (q.data?.unread) api("/notifications/read", { method: "POST" }).then(() => qc.invalidateQueries({ queryKey: ["/notifications"] }));
  }, [q.data?.unread, qc]);

  return (
    <View style={{ flex: 1, backgroundColor: colors.surface }}>
      <Header title="الإشعارات" />
      {q.isLoading ? (
        <Loading />
      ) : (
        <FlatList
          testID="notifications-list"
          data={q.data?.items ?? []}
          keyExtractor={(n) => n.id}
          contentContainerStyle={{ padding: 16, gap: 8, paddingBottom: insets.bottom + 24, flexGrow: 1 }}
          ListEmptyComponent={<Empty testID="notifications-empty" icon="notifications-off" title="مفيش إشعارات" body="هنبلغك بالعروض الجديدة وتحديثات طلباتك هنا" />}
          renderItem={({ item }) => (
            <Card
              testID={`notification-${item.id}`}
              onPress={item.request_id ? () => router.push(`/request/${item.request_id}`) : undefined}
              style={{ backgroundColor: item.read ? colors.surfaceSecondary : colors.surfaceTertiary }}
            >
              <Row gap={12} style={{ alignItems: "flex-start" }}>
                <View style={{ width: 40, height: 40, borderRadius: 20, backgroundColor: colors.brandTertiary, alignItems: "center", justifyContent: "center" }}>
                  <Icon name="notifications" size={20} color={colors.brand} />
                </View>
                <View style={{ flex: 1 }}>
                  <Row style={{ justifyContent: "space-between" }}>
                    <Txt weight="700" style={{ flex: 1 }}>
                      {item.title}
                    </Txt>
                    <Txt variant="caption" color={colors.muted}>
                      {timeAgo(item.created_at)}
                    </Txt>
                  </Row>
                  <Txt variant="caption" color={colors.onSurfaceSecondary}>
                    {item.body}
                  </Txt>
                </View>
              </Row>
            </Card>
          )}
        />
      )}
    </View>
  );
}