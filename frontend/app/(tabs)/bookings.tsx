import { useState } from "react";
import { FlatList, RefreshControl, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { useRouter } from "expo-router";
import { useApi } from "@/src/api";
import { useAuth } from "@/src/auth";
import { Btn, Chip, ChipRow, Empty, ErrorView, Loading, Txt } from "@/src/ui";
import { useTheme } from "@/src/theme";
import { usesNativeTabs } from "@/src/navigation";
import { RequestCard } from "@/src/components/RequestCard";

const FILTERS = [
  { id: "all", label: "الكل" },
  { id: "active", label: "نشطة" },
  { id: "completed", label: "مكتملة" },
  { id: "cancelled", label: "ملغية" },
];

export default function Bookings() {
  const { colors } = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const { user } = useAuth();
  const [filter, setFilter] = useState("all");
  const q = useApi<any[]>(user?.role === "admin" ? "/admin/requests" : "/requests");
  const bottomChrome = usesNativeTabs ? insets.bottom : 0;
  const items = (q.data ?? []).filter((r) =>
    filter === "all" ? true : filter === "active" ? !["completed", "cancelled"].includes(r.status) : r.status === filter,
  );

  return (
    <View style={{ flex: 1, backgroundColor: colors.surface }}>
      <View style={{ paddingTop: insets.top + 8, backgroundColor: colors.surfaceSecondary, borderBottomWidth: 1, borderBottomColor: colors.border }}>
        <Txt variant="h1" style={{ paddingHorizontal: 16 }}>
          {user?.role === "technician" ? "شغلي" : user?.role === "admin" ? "كل الطلبات" : "طلباتي"}
        </Txt>
        <ChipRow testID="bookings-filter-row">
          {FILTERS.map((f) => (
            <Chip key={f.id} testID={`bookings-filter-${f.id}`} label={f.label} selected={filter === f.id} onPress={() => setFilter(f.id)} />
          ))}
        </ChipRow>
      </View>
      {q.isLoading ? (
        <Loading />
      ) : q.isError ? (
        <ErrorView message={(q.error as Error).message} onRetry={() => q.refetch()} />
      ) : (
        <FlatList
          testID="bookings-list"
          data={items}
          keyExtractor={(r) => r.id}
          contentContainerStyle={{ padding: 16, gap: 12, paddingBottom: bottomChrome + 24, flexGrow: 1 }}
          refreshControl={<RefreshControl refreshing={q.isRefetching} onRefresh={() => q.refetch()} tintColor={colors.brand} />}
          renderItem={({ item, index }) => <RequestCard r={item} index={index} />}
          ListEmptyComponent={
            <Empty
              testID="bookings-empty"
              icon="calendar-clear"
              title="مفيش طلبات هنا"
              body={user?.role === "customer" ? "اطلب أول خدمة وقارن عروض الفنيين" : "الطلبات هتظهر هنا"}
              action={
                user?.role === "customer" ? (
                  <Btn testID="bookings-new-request-button" small label="اطلب خدمة" icon="add" onPress={() => router.push("/request/new")} />
                ) : undefined
              }
            />
          }
        />
      )}
    </View>
  );
}