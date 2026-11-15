import { useState } from "react";
import { Linking, RefreshControl, View } from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { KeyboardAwareScrollView } from "react-native-keyboard-controller";
import Animated, { FadeInDown } from "react-native-reanimated";
import * as Haptics from "expo-haptics";
import { useQueryClient } from "@tanstack/react-query";
import { api, useApi } from "@/src/api";
import { useAuth } from "@/src/auth";
import { Badge, Btn, Card, Chip, ChipRow, Empty, ErrorView, Field, Header, Icon, IconName, Loading, Row, SectionTitle, Stars, Txt, useToast } from "@/src/ui";
import { useTheme } from "@/src/theme";
import { dateTimeFmt, egp, FLOW, phoneFmt, STATUS } from "@/src/format";

const NEXT: Record<string, { status: string; label: string; icon: IconName }> = {
  booked: { status: "on_the_way", label: "بدأت التحرك للعميل", icon: "car" },
  on_the_way: { status: "arrived", label: "وصلت للعنوان", icon: "location" },
  arrived: { status: "in_progress", label: "بدء العمل", icon: "construct" },
  in_progress: { status: "completed", label: "تم الإنجاز", icon: "checkmark-done" },
};

export default function RequestDetail() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { colors } = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const toast = useToast();
  const qc = useQueryClient();
  const { user } = useAuth();
  const isCustomer = user?.role === "customer";
  const isTech = user?.role === "technician";
  const q = useApi<any>(`/requests/${id}`, 8000);
  const r = q.data;
  const [sort, setSort] = useState<"price" | "rating" | "eta">("price");
  const offers = useApi<any[]>(isCustomer && r?.status === "open" ? `/requests/${id}/offers?sort=${sort}` : null, 8000);
  const [busy, setBusy] = useState<string | null>(null);
  const [price, setPrice] = useState("");
  const [eta, setEta] = useState("60");
  const [note, setNote] = useState("");
  const [rating, setRating] = useState(0);
  const [comment, setComment] = useState("");

  const act = async (key: string, fn: () => Promise<any>, ok: string) => {
    setBusy(key);
    try {
      await fn();
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
      toast(ok);
      await q.refetch();
      offers.refetch();
      qc.invalidateQueries({ queryKey: ["/requests"] });
    } catch (e: any) {
      toast(e.message, "error");
    } finally {
      setBusy(null);
    }
  };

  if (q.isLoading)
    return (
      <View style={{ flex: 1, backgroundColor: colors.surface }}>
        <Header title="تفاصيل الطلب" />
        <Loading />
      </View>
    );
  if (q.isError || !r)
    return (
      <View style={{ flex: 1, backgroundColor: colors.surface }}>
        <Header title="تفاصيل الطلب" />
        <ErrorView message={(q.error as Error)?.message} onRetry={() => q.refetch()} />
      </View>
    );

  const st = STATUS[r.status] ?? STATUS.open;
  const flowIdx = FLOW.indexOf(r.status);
  const list = offers.data ?? [];
  const minPrice = Math.min(...list.map((o) => o.price));
  const maxRating = Math.max(...list.map((o) => o.rating));
  const assignedToMe = isTech && r.technician_id === user?.id;
  const mapsUrl =
    r.lat != null
      ? `https://www.google.com/maps/search/?api=1&query=${r.lat},${r.lng}`
      : r.address
        ? `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(r.address + "، " + r.area + "، المنصورة")}`
        : null;

  return (
    <View style={{ flex: 1, backgroundColor: colors.surface }}>
      <Header title={`${r.category_name}`} subtitle={r.service_name} />
      <KeyboardAwareScrollView
        bottomOffset={24}
        keyboardShouldPersistTaps="handled"
        contentContainerStyle={{ padding: 16, gap: 16, paddingBottom: insets.bottom + 32 }}
        refreshControl={<RefreshControl refreshing={q.isRefetching} onRefresh={() => q.refetch()} tintColor={colors.brand} />}
      >
        <Card testID="request-status-card" style={{ gap: 12, backgroundColor: colors.surfaceTertiary, borderColor: colors.brandTertiary }}>
          <Row style={{ justifyContent: "space-between" }}>
            <Row gap={8}>
              <Icon name={st.icon as IconName} size={24} color={colors.brand} />
              <Txt variant="h2" color={colors.onSurfaceTertiary} testID="request-status-label">
                {st.label}
              </Txt>
            </Row>
            {r.urgency === "urgent" ? <Badge label="عاجل" tone="error" icon="flash" /> : null}
          </Row>
          <Txt color={colors.onSurfaceTertiary}>{dateTimeFmt(r.scheduled_at)}</Txt>
          {r.price ? (
            <Txt variant="h1" color={colors.brand} testID="request-price">
              {egp(r.price)}
            </Txt>
          ) : null}
        </Card>

        {r.status !== "open" && r.status !== "cancelled" ? (
          <Card style={{ gap: 0 }} testID="request-tracking">
            <SectionTitle title="تتبع الطلب" />
            {FLOW.map((s, i) => {
              const done = i <= flowIdx;
              const at = r.timeline?.find((t: any) => t.status === s)?.at;
              return (
                <Row key={s} gap={12} style={{ alignItems: "flex-start" }}>
                  <View style={{ alignItems: "center" }}>
                    <View
                      style={{
                        width: 28,
                        height: 28,
                        borderRadius: 14,
                        backgroundColor: done ? colors.brand : colors.divider,
                        alignItems: "center",
                        justifyContent: "center",
                      }}
                    >
                      <Icon name={done ? "checkmark" : (STATUS[s].icon as IconName)} size={14} color={done ? colors.onBrand : colors.muted} />
                    </View>
                    {i < FLOW.length - 1 ? <View style={{ width: 2, height: 24, backgroundColor: i < flowIdx ? colors.brand : colors.divider }} /> : null}
                  </View>
                  <View style={{ flex: 1, paddingTop: 2 }}>
                    <Txt weight={i === flowIdx ? "700" : "400"} color={done ? colors.onSurface : colors.muted}>
                      {STATUS[s].label}
                    </Txt>
                    {at ? (
                      <Txt variant="caption" color={colors.muted}>
                        {dateTimeFmt(at)}
                      </Txt>
                    ) : null}
                  </View>
                </Row>
              );
            })}
          </Card>
        ) : null}

        {r.technician_name && !isTech ? (
          <Card style={{ gap: 12 }} testID="request-technician-card">
            <Row gap={12}>
              <View style={{ width: 52, height: 52, borderRadius: 26, backgroundColor: colors.brand, alignItems: "center", justifyContent: "center" }}>
                <Txt variant="h2" color={colors.onBrand} center>
                  {r.technician_name[0]}
                </Txt>
              </View>
              <View style={{ flex: 1 }}>
                <Txt variant="title">{r.technician_name}</Txt>
                <Row gap={4}>
                  <Icon name="shield-checkmark" size={14} color={colors.brand} />
                  <Txt variant="caption" color={colors.brand}>
                    فني موثق
                  </Txt>
                </Row>
              </View>
            </Row>
            <Row gap={8}>
              <Btn testID="request-chat-button" small label="محادثة" icon="chatbubbles" onPress={() => router.push(`/chat/${r.id}`)} style={{ flex: 1 }} />
              {r.technician_phone ? (
                <Btn testID="request-call-button" small variant="outline" label="اتصال" icon="call" onPress={() => Linking.openURL(`tel:${r.technician_phone}`)} style={{ flex: 1 }} />
              ) : null}
            </Row>
          </Card>
        ) : null}

        <Card style={{ gap: 12 }} testID="request-details-card">
          <SectionTitle title="تفاصيل المشكلة" />
          <Txt>{r.description}</Txt>
          <Row gap={8} style={{ alignItems: "flex-start" }}>
            <Icon name="location" size={18} color={colors.brand} />
            <Txt style={{ flex: 1 }}>
              {r.area}
              {r.address ? ` — ${r.address}` : " (العنوان الكامل يظهر بعد قبول عرضك)"}
            </Txt>
          </Row>
          <Row gap={8}>
            <Icon name={r.payment_method === "cash" ? "cash" : "card"} size={18} color={colors.brand} />
            <Txt>{r.payment_method === "cash" ? "الدفع كاش بعد الشغل" : "دفع إلكتروني"}</Txt>
          </Row>
          {r.price_min ? (
            <Txt variant="caption" color={colors.muted}>
              السعر الاسترشادي: {r.price_min} - {egp(r.price_max)}
            </Txt>
          ) : null}
          {isTech && assignedToMe ? (
            <Row gap={8}>
              {mapsUrl ? <Btn testID="request-open-maps-button" small variant="soft" icon="map" label="افتح في الخرائط" onPress={() => Linking.openURL(mapsUrl)} style={{ flex: 1 }} /> : null}
              {r.customer_phone ? (
                <Btn testID="request-call-customer-button" small variant="outline" icon="call" label={phoneFmt(r.customer_phone)} onPress={() => Linking.openURL(`tel:${r.customer_phone}`)} />
              ) : null}
            </Row>
          ) : null}
          {assignedToMe ? (
            <Btn testID="request-tech-chat-button" small variant="outline" icon="chatbubbles" label={`محادثة ${r.customer_name}`} onPress={() => router.push(`/chat/${r.id}`)} />
          ) : null}
        </Card>

        {isCustomer && r.status === "open" ? (
          <View style={{ gap: 8 }}>
            <SectionTitle title="قارن العروض" action={<Badge label={`${list.length} عروض`} tone="info" />} />
            <View style={{ marginHorizontal: -16 }}>
              <ChipRow testID="offers-sort-row">
                <Chip testID="offers-sort-price" label="الأقل سعرًا" icon="pricetag" selected={sort === "price"} onPress={() => setSort("price")} />
                <Chip testID="offers-sort-rating" label="الأعلى تقييمًا" icon="star" selected={sort === "rating"} onPress={() => setSort("rating")} />
                <Chip testID="offers-sort-eta" label="الأسرع وصولاً" icon="time" selected={sort === "eta"} onPress={() => setSort("eta")} />
              </ChipRow>
            </View>
            {!list.length ? (
              <Empty testID="offers-empty" icon="hourglass" title="بنجمع العروض من الفنيين" body="هيوصلك إشعار أول ما فني يقدم عرض. الصفحة بتتحدث تلقائي." />
            ) : (
              list.map((o, i) => (
                <Animated.View key={o.id} entering={FadeInDown.delay(i * 60)}>
                  <Card testID={`offer-card-${i}`} style={{ gap: 12, borderColor: o.price === minPrice ? colors.brand : colors.border, borderWidth: o.price === minPrice ? 2 : 1 }}>
                    <Row style={{ justifyContent: "space-between", alignItems: "flex-start" }}>
                      <Row gap={12} style={{ flex: 1 }}>
                        <View style={{ width: 48, height: 48, borderRadius: 24, backgroundColor: colors.brandTertiary, alignItems: "center", justifyContent: "center" }}>
                          <Txt variant="title" color={colors.brand} center>
                            {o.technician_name[0]}
                          </Txt>
                        </View>
                        <View style={{ flex: 1 }}>
                          <Txt variant="title">{o.technician_name}</Txt>
                          <Row gap={6}>
                            <Stars value={o.rating} size={13} />
                            <Txt variant="caption" color={colors.muted}>
                              {o.rating ? o.rating.toFixed(1) : "جديد"} • {o.jobs_done} شغلانة
                            </Txt>
                          </Row>
                        </View>
                      </Row>
                      <Txt variant="h2" color={colors.brand} testID={`offer-price-${i}`}>
                        {egp(o.price)}
                      </Txt>
                    </Row>
                    <Row gap={8} style={{ flexWrap: "wrap" }}>
                      {o.price === minPrice ? <Badge label="أقل سعر" tone="success" icon="pricetag" /> : null}
                      {o.rating === maxRating && o.rating > 0 ? <Badge label="الأعلى تقييمًا" tone="warning" icon="star" /> : null}
                      <Badge label={`يوصل خلال ${o.eta_minutes} دقيقة`} tone="muted" icon="time" />
                    </Row>
                    {o.note ? <Txt variant="caption" color={colors.onSurfaceSecondary}>“{o.note}”</Txt> : null}
                    <Btn
                      testID={`offer-accept-button-${i}`}
                      label="اختار العرض ده واحجز"
                      icon="checkmark-circle"
                      loading={busy === o.id}
                      onPress={() => act(o.id, () => api(`/offers/${o.id}/accept`, { method: "POST" }), "تم الحجز! الفني هيتواصل معاك")}
                    />
                  </Card>
                </Animated.View>
              ))
            )}
          </View>
        ) : null}

        {isTech && r.status === "open" ? (
          r.my_offer ? (
            <Card testID="tech-my-offer" style={{ gap: 8 }}>
              <SectionTitle title="عرضك" action={<Badge label="بانتظار رد العميل" tone="warning" />} />
              <Txt variant="h2" color={colors.brand}>
                {egp(r.my_offer.price)}
              </Txt>
              <Txt variant="caption" color={colors.muted}>
                الوصول خلال {r.my_offer.eta_minutes} دقيقة
              </Txt>
            </Card>
          ) : (
            <Card testID="tech-offer-form" style={{ gap: 12 }}>
              <SectionTitle title="قدّم عرضك" />
              <Field testID="offer-price-input" label="السعر (ج.م)" keyboardType="number-pad" value={price} onChangeText={setPrice} placeholder={r.price_min ? `${r.price_min}` : "200"} />
              <Field testID="offer-eta-input" label="الوصول خلال (دقيقة)" keyboardType="number-pad" value={eta} onChangeText={setEta} />
              <Field testID="offer-note-input" label="ملاحظة للعميل" value={note} onChangeText={setNote} placeholder="مثال: معايا قطع الغيار الأصلية" />
              <Btn
                testID="offer-submit-button"
                label="إرسال العرض"
                icon="paper-plane"
                disabled={!Number(price) || !Number(eta)}
                loading={busy === "offer"}
                onPress={() =>
                  act("offer", () => api(`/requests/${id}/offers`, { body: { price: Number(price), eta_minutes: Number(eta), note } }), "تم إرسال عرضك للعميل")
                }
              />
            </Card>
          )
        ) : null}

        {assignedToMe && NEXT[r.status] ? (
          <Btn
            testID="tech-next-status-button"
            label={r.status === "in_progress" ? `تم الإنجاز واستلام ${egp(r.price)}${r.payment_method === "cash" ? " كاش" : ""}` : NEXT[r.status].label}
            icon={NEXT[r.status].icon}
            loading={busy === "status"}
            onPress={() => act("status", () => api(`/requests/${id}/status`, { body: { status: NEXT[r.status].status } }), "تم تحديث الحالة")}
          />
        ) : null}

        {r.payment ? (
          <Card testID="request-payment-card" style={{ gap: 8 }}>
            <SectionTitle title="سجل الدفع" action={<Badge label={r.payment.status === "collected" ? "تم التحصيل" : "بانتظار الدفع"} tone={r.payment.status === "collected" ? "success" : "warning"} />} />
            <Row style={{ justifyContent: "space-between" }}>
              <Txt>{r.payment.method === "cash" ? "كاش للفني" : "دفع إلكتروني"}</Txt>
              <Txt variant="title" color={colors.brand}>
                {egp(r.payment.amount)}
              </Txt>
            </Row>
            <Txt variant="caption" color={colors.muted}>
              {dateTimeFmt(r.payment.created_at)}
            </Txt>
          </Card>
        ) : null}

        {r.status === "completed" && r.review ? (
          <Card testID="request-review-display" style={{ gap: 8 }}>
            <SectionTitle title="التقييم" />
            <Stars value={r.review.rating} size={20} />
            {r.review.comment ? <Txt>{r.review.comment}</Txt> : null}
          </Card>
        ) : null}
        {isCustomer && r.status === "completed" && !r.review ? (
          <Card testID="request-review-form" style={{ gap: 12 }}>
            <SectionTitle title={`قيّم ${r.technician_name}`} />
            <Stars value={rating} size={36} onChange={setRating} testIDPrefix="review-star" />
            <Field testID="review-comment-input" placeholder="احكي تجربتك (اختياري)" value={comment} onChangeText={setComment} multiline style={{ minHeight: 88 }} />
            <Btn
              testID="review-submit-button"
              label="إرسال التقييم"
              icon="star"
              disabled={!rating}
              loading={busy === "review"}
              onPress={() => act("review", () => api(`/requests/${id}/review`, { body: { rating, comment } }), "شكرًا على تقييمك!")}
            />
          </Card>
        ) : null}

        {isCustomer && ["open", "booked"].includes(r.status) ? (
          <Btn
            testID="request-cancel-button"
            variant="danger"
            label="إلغاء الطلب"
            icon="close-circle"
            loading={busy === "cancel"}
            onPress={() => act("cancel", () => api(`/requests/${id}/cancel`, { method: "POST" }), "تم إلغاء الطلب")}
          />
        ) : null}
      </KeyboardAwareScrollView>
    </View>
  );
}