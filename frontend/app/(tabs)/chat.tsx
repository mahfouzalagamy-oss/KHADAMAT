import { FlatList, RefreshControl, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { useRouter } from "expo-router";
import { useApi } from "@/src/api";
import { useAuth } from "@/src/auth";
import { Badge, Card, Empty, ErrorView, Loading, Row, Txt } from "@/src/ui";
import { useTheme } from "@/src/theme";
import { usesNativeTabs } from "@/src/navigation";
import { STATUS, timeAgo } from "@/src/format";

export default function Chats() {
  const { colors } = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const { user } = useAuth();
  const canChat = user?.role === "customer" || user?.role === "technician";
  const q = useApi<any[]>(canChat ? "/chats" : null, 10000);
  const bottomChrome = usesNativeTabs ? insets.bottom : 0;

  return (
    <View style={{ flex: 1, backgroundColor: colors.surface }}>
      <View style={{ paddingTop: insets.top + 8, paddingHorizontal: 16, paddingBottom: 12, backgroundColor: colors.surfaceSecondary, borderBottomWidth: 1, borderBottomColor: colors.border }}>
        <Txt variant="h1">المحادثات</Txt>
      </View>
      {!canChat ? (
        <Empty icon="chatbubbles" title="المحادثات للعملاء والفنيين" body="بتظهر المحادثة بعد تأكيد أي حجز" />
      ) : q.isLoading ? (
        <Loading />
      ) : q.isError ? (
        <ErrorView message={(q.error as Error).message} onRetry={() => q.refetch()} />
      ) : (
        <FlatList
          testID="chats-list"
          data={q.data}
          keyExtractor={(c) => c.request_id}
          contentContainerStyle={{ padding: 16, gap: 12, paddingBottom: bottomChrome + 24, flexGrow: 1 }}
          refreshControl={<RefreshControl refreshing={q.isRefetching} onRefresh={() => q.refetch()} tintColor={colors.brand} />}
          ListEmptyComponent={<Empty testID="chats-empty" icon="chatbubble-ellipses" title="مفيش محادثات لسه" body="بعد ما تحجز، تقدر تكلم الفني من هنا" />}
          renderItem={({ item }) => (
            <Card testID={`chat-row-${item.request_id}`} onPress={() => router.push(`/chat/${item.request_id}`)}>
              <Row gap={12}>
                <View style={{ width: 48, height: 48, borderRadius: 24, backgroundColor: colors.brand, alignItems: "center", justifyContent: "center" }}>
                  <Txt variant="title" color={colors.onBrand} center>
                    {item.other_name?.[0]}
                  </Txt>
                </View>
                <View style={{ flex: 1 }}>
                  <Row style={{ justifyContent: "space-between" }}>
                    <Txt variant="title" numberOfLines={1} style={{ flex: 1 }}>
                      {item.other_name}
                    </Txt>
                    <Txt variant="caption" color={colors.muted}>
                      {timeAgo(item.last_at)}
                    </Txt>
                  </Row>
                  <Txt variant="caption" color={colors.muted} numberOfLines={1}>
                    {item.last_message ?? `${item.category_name} — ابدأ المحادثة`}
                  </Txt>
                </View>
              </Row>
              <View style={{ marginTop: 8 }}>
                <Badge label={STATUS[item.status]?.label ?? item.status} tone={STATUS[item.status]?.tone ?? "muted"} />
              </View>
            </Card>
          )}
        />
      )}
    </View>
  );
}