import { useEffect, useState } from "react";
import { Pressable, View } from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { KeyboardAwareScrollView } from "react-native-keyboard-controller";
import * as Location from "expo-location";
import * as Haptics from "expo-haptics";
import { Image } from "expo-image";
import { useQueryClient } from "@tanstack/react-query";
import { api, useApi } from "@/src/api";
import { pickAndUploadImage, resolveMediaUrl } from "@/src/utils/pick-and-upload";
import { storage } from "@/src/utils/storage";
import { useOnline } from "@/src/utils/online";
import { Badge, Btn, Card, Chip, ChipRow, Field, Header, Icon, IconName, Row, SectionTitle, Txt, useToast } from "@/src/ui";
import { useTheme } from "@/src/theme";
import { egp } from "@/src/format";

export const DRAFT_KEY = "request_draft_locked_v3";

type Draft = {
  category_id: string;
  service_id: string | null;
  description: string;
  urgency: "normal" | "urgent";
  area: string;
  address: string;
  lat: number | null;
  lng: number | null;
  day: "today" | "tomorrow";
  slot: string;
  payment_method: "cash" | "online";
  photos: string[];
};

const SLOTS = [
  { id: "10:00", label: "صباحًا (10 ص - 1 م)" },
  { id: "14:00", label: "ظهرًا (1 م - 5 م)" },
  { id: "18:00", label: "مساءً (5 م - 9 م)" },
  { id: "21:00", label: "ليلاً (9 م - 11 م)" },
];

const INIT: Draft = {
  category_id: "",
  service_id: null,
  description: "",
  urgency: "normal",
  area: "حي الجامعة",
  address: "",
  lat: null,
  lng: null,
  day: "today",
  slot: "18:00",
  payment_method: "cash",
  photos: [],
};

export default function NewRequest() {
  const { colors } = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const qc = useQueryClient();
  const toast = useToast();
  const online = useOnline();
  const params = useLocalSearchParams<{ category_id?: string; category?: string; service_id?: string; service?: string }>();
  const paramCategoryId = params.category_id || params.category || "";
  const paramServiceId = params.service_id || params.service || null;

  const cat = useApi<any>("/catalog");
  const pay = useApi<any>("/payments/config");

  const [step, setStep] = useState(0);
  const [d, setD] = useState<Draft>(() => ({
    ...INIT,
    category_id: paramCategoryId,
    service_id: paramServiceId,
  }));
  const [ready, setReady] = useState(false);
  const [aiBusy, setAiBusy] = useState(false);
  const [uploadingPhoto, setUploadingPhoto] = useState(false);
  const [aiPrice, setAiPrice] = useState<{ min: number; max: number } | null>(null);
  const [aiTips, setAiTips] = useState<string[]>([]);
  const [locBusy, setLocBusy] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    storage.get<Draft | null>(DRAFT_KEY, null).then((saved) => {
      if (paramCategoryId) {
        setD({
          ...INIT,
          ...(saved && saved.category_id === paramCategoryId ? saved : {}),
          category_id: paramCategoryId,
          service_id: paramServiceId ?? (saved && saved.category_id === paramCategoryId ? saved.service_id : null),
        });
      } else if (saved) {
        setD({ ...INIT, ...saved });
      }
      setReady(true);
    });
  }, [paramCategoryId, paramServiceId]);

  useEffect(() => {
    if (ready) storage.set(DRAFT_KEY, d);
  }, [d, ready]);

  const set = (p: Partial<Draft>) => setD((prev) => ({ ...prev, ...p }));
  const categories = cat.data?.categories ?? [];
  const areas = cat.data?.areas ?? [
    "حي الجامعة", "توريل", "المشاية", "جديلة", "سندوب",
    "طلخا", "ميت غمر", "السنبلاوين", "بلقاس", "شربين", "دكرنس", "منية النصر", "أجا",
  ];

  const activeCategoryId = paramCategoryId || d.category_id;
  const activeServiceId = paramServiceId || d.service_id;
  const curCat = categories.find((c: any) => c.id === activeCategoryId);
  const curSrv = curCat?.services?.find((s: any) => s.id === activeServiceId);

  const runAi = async () => {
    if (d.description.trim().length < 3) return toast("اكتب كلمتين عن المشكلة الأول", "info");
    setAiBusy(true);
    try {
      const r = await api("/ai/describe", { body: { text: d.description, category_id: activeCategoryId || undefined } });
      set({
        description: r.description,
        category_id: activeCategoryId || r.suggested_category_id || "plumbing",
        urgency: r.urgency,
      });
      setAiPrice({ min: r.price_min, max: r.price_max });
      setAiTips(r.tips ?? []);
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      toast("تم ترتيب الوصف وتقدير السعر");
    } catch (e: any) {
      toast(e.message, "error");
    } finally {
      setAiBusy(false);
    }
  };

  const grabGps = async () => {
    setLocBusy(true);
    try {
      const { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== "granted") {
        toast("محتاجين إذن الموقع أو اكتب العنوان يدويًا", "info");
        return;
      }
      const pos = await Location.getCurrentPositionAsync({});
      set({
        lat: pos.coords.latitude,
        lng: pos.coords.longitude,
        address: d.address || `موقعي الحالي (${pos.coords.latitude.toFixed(4)}, ${pos.coords.longitude.toFixed(4)})`,
      });
      toast("تم تحديد موقعك على الخريطة");
    } catch {
      toast("تعذر تحديد الموقع، اكتب العنوان يدويًا", "info");
    } finally {
      setLocBusy(false);
    }
  };

  const submit = async () => {
    if (!online) return toast("أنت غير متصل حاليًا. مسودتك محفوظة وهتقدر تبعتها أول ما النت يرجع.", "info");
    setSubmitting(true);
    try {
      const base = new Date();
      if (d.day === "tomorrow") base.setDate(base.getDate() + 1);
      const [hh, mm] = d.slot.split(":").map(Number);
      base.setHours(hh, mm, 0, 0);
      const created = await api("/requests", {
        body: {
          category_id: activeCategoryId || "plumbing",
          service_id: activeServiceId,
          description: d.description.trim(),
          urgency: d.urgency,
          area: d.area,
          address: d.address.trim(),
          lat: d.lat,
          lng: d.lng,
          scheduled_at: base.toISOString(),
          payment_method: d.payment_method,
          photos: d.photos ?? [],
        },
      });
      await storage.del(DRAFT_KEY);
      qc.invalidateQueries({ queryKey: ["/requests"] });
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      toast("تم إرسال طلبك! العروض هتوصلك خلال ثواني");
      router.replace(`/request/${created.id}`);
    } catch (e: any) {
      toast(e.message, "error");
    } finally {
      setSubmitting(false);
    }
  };

  const canNext =
    (step === 0 && !!activeCategoryId && d.description.trim().length >= 4) ||
    (step === 1 && d.address.trim().length >= 4 && !!d.area) ||
    step === 2;
  const steps = ["المشكلة", "الموقع", "الموعد", "التأكيد"];

  return (
    <View style={{ flex: 1, backgroundColor: colors.surface }}>
      <Header
        title="طلب خدمة جديد"
        subtitle={`${curCat?.name ?? "اختر القسم"}${curSrv ? " • " + curSrv.name : ""}`}
        onBack={() => (step > 0 ? setStep(step - 1) : router.back())}
        right={<Badge testID="draft-saved-badge" label="مسودة محفوظة" tone="neutral" icon="save" />}
      />

      <View style={{ paddingHorizontal: 16, paddingTop: 12, gap: 8 }}>
        <Row gap={6}>
          {steps.map((s, i) => (
            <View key={s} style={{ flex: 1, height: 6, borderRadius: 999, backgroundColor: i <= step ? colors.brand : colors.border }} />
          ))}
        </Row>
        <Row style={{ justifyContent: "space-between" }}>
          {steps.map((s, i) => (
            <Txt key={s} variant="caption" weight={i === step ? "700" : "500"} color={i <= step ? colors.brand : colors.muted}>
              {s}
            </Txt>
          ))}
        </Row>
      </View>

      <KeyboardAwareScrollView
        bottomOffset={24}
        keyboardShouldPersistTaps="handled"
        contentContainerStyle={{ padding: 16, gap: 16, paddingBottom: insets.bottom + 32 }}
      >
        {step === 0 ? (
          <>
            <Txt variant="title">نوع الخدمة</Txt>

            {curCat ? (
              <Card
                testID={`wizard-category-${curCat.id}`}
                style={{ backgroundColor: colors.brandTertiary, borderColor: colors.brand, borderWidth: 2 }}
              >
                <Row style={{ justifyContent: "space-between" }}>
                  <Row gap={10}>
                    <View
                      style={{
                        width: 40,
                        height: 40,
                        borderRadius: 12,
                        backgroundColor: colors.brand,
                        alignItems: "center",
                        justifyContent: "center",
                      }}
                    >
                      <Icon name={curCat.icon as IconName} size={20} color={colors.onBrand} />
                    </View>
                    <View>
                      <Txt weight="700" color={colors.onBrandTertiary}>
                        {curCat.name}
                        {curSrv ? ` • ${curSrv.name}` : ""}
                      </Txt>
                      {curSrv ? (
                        <Txt variant="caption" color={colors.brand}>
                          السعر الاسترشادي: {egp(curSrv.min)} – {egp(curSrv.max)}
                        </Txt>
                      ) : null}
                    </View>
                  </Row>
                  <Badge label="الخدمة المختارة" tone="success" icon="checkmark-circle" />
                </Row>
              </Card>
            ) : (
              <ChipRow>
                {categories.map((c: any) => (
                  <Chip
                    key={c.id}
                    testID={`wizard-category-${c.id}`}
                    label={c.name}
                    icon={c.icon as IconName}
                    selected={false}
                    onPress={() => set({ category_id: c.id, service_id: null })}
                  />
                ))}
              </ChipRow>
            )}

            <Field
              testID="wizard-description-input"
              label="اوصف المشكلة"
              placeholder="مثال: الحوض في المطبخ بيسرب مية من تحت ومش بيصرف كويس"
              multiline
              value={d.description}
              onChangeText={(v) => set({ description: v })}
            />
            <Btn
              testID="wizard-ai-button"
              variant="soft"
              icon="sparkles"
              label="رتّب الوصف بالذكاء الاصطناعي"
              loading={aiBusy}
              disabled={d.description.trim().length < 3}
              onPress={runAi}
            />
            {aiPrice ? (
              <Card testID="wizard-ai-result" style={{ backgroundColor: colors.brandTertiary, borderColor: colors.brand, gap: 6 }}>
                <Row gap={8}>
                  <Icon name="pricetag" size={18} color={colors.brand} />
                  <Txt weight="700" color={colors.onBrandTertiary}>
                    التكلفة المتوقعة في المنصورة: {egp(aiPrice.min)} – {egp(aiPrice.max)}
                  </Txt>
                </Row>
                {aiTips.map((t, i) => (
                  <Txt key={i} variant="caption" color={colors.onBrandTertiary}>
                    • {t}
                  </Txt>
                ))}
              </Card>
            ) : null}

            <Txt variant="title">صور المشكلة (اختياري)</Txt>
            <Row gap={8} style={{ flexWrap: "wrap" }}>
              {(d.photos ?? []).map((u, idx) => (
                <Pressable
                  key={u}
                  testID={`wizard-photo-${idx}`}
                  onPress={() => set({ photos: (d.photos ?? []).filter((x) => x !== u) })}
                  style={{ width: 68, height: 68, borderRadius: 12, overflow: "hidden", borderWidth: 1, borderColor: colors.border }}
                >
                  <Image source={{ uri: resolveMediaUrl(u) }} style={{ width: "100%", height: "100%" }} contentFit="cover" />
                </Pressable>
              ))}
              {(d.photos?.length ?? 0) < 4 ? (
                <Btn
                  testID="wizard-add-photo-button"
                  small
                  variant="outline"
                  icon="camera"
                  label="إضافة صورة"
                  loading={uploadingPhoto}
                  onPress={async () => {
                    if (!online) return toast("رفع الصور يحتاج اتصال بالإنترنت", "info");
                    setUploadingPhoto(true);
                    try {
                      const url = await pickAndUploadImage();
                      if (url) set({ photos: [...(d.photos ?? []), url] });
                    } catch (e: any) {
                      toast(e.message || "فشل رفع الصورة", "error");
                    } finally {
                      setUploadingPhoto(false);
                    }
                  }}
                />
              ) : null}
            </Row>

            <Txt variant="title">مدى الاستعجال</Txt>
            <Row gap={12}>
              {(
                [
                  { id: "normal", label: "عادي", icon: "time" },
                  { id: "urgent", label: "عاجل", icon: "flash" },
                ] as const
              ).map((u) => {
                const sel = d.urgency === u.id;
                return (
                  <Pressable
                    key={u.id}
                    testID={`wizard-urgency-${u.id}`}
                    onPress={() => set({ urgency: u.id })}
                    style={{
                      flex: 1,
                      minHeight: 52,
                      borderRadius: 16,
                      borderWidth: 2,
                      borderColor: sel ? colors.brand : colors.border,
                      backgroundColor: sel ? colors.brandTertiary : colors.surfaceSecondary,
                      alignItems: "center",
                      justifyContent: "center",
                      flexDirection: "row-reverse",
                      gap: 8,
                    }}
                  >
                    <Icon name={u.icon as IconName} size={18} color={sel ? colors.brand : colors.muted} />
                    <Txt weight="700" color={sel ? colors.onBrandTertiary : colors.onSurface}>
                      {u.label}
                    </Txt>
                  </Pressable>
                );
              })}
            </Row>
          </>
        ) : null}

        {step === 1 ? (
          <>
            <Txt variant="title">المنطقة في المنصورة والدقهلية</Txt>
            <View style={{ flexDirection: "row-reverse", flexWrap: "wrap", gap: 8 }}>
              {areas.map((a: string) => (
                <Chip key={a} testID={`wizard-area-${a}`} label={a} selected={d.area === a} onPress={() => set({ area: a })} />
              ))}
            </View>
            <Field
              testID="wizard-address-input"
              label="العنوان بالتفصيل"
              placeholder="الشارع، رقم العمارة، الدور، علامة مميزة"
              value={d.address}
              onChangeText={(v) => set({ address: v })}
            />
            <Btn testID="wizard-gps-button" variant="outline" icon="locate" label={d.lat ? "تم تحديد موقعك ✓" : "استخدم موقعي الحالي (GPS)"} loading={locBusy} onPress={grabGps} />
          </>
        ) : null}

        {step === 2 ? (
          <>
            <Txt variant="title">اليوم</Txt>
            <Row gap={12}>
              {(
                [
                  { id: "today", label: "النهارده" },
                  { id: "tomorrow", label: "بكرة" },
                ] as const
              ).map((x) => {
                const sel = d.day === x.id;
                return (
                  <Pressable
                    key={x.id}
                    testID={`wizard-day-${x.id}`}
                    onPress={() => set({ day: x.id })}
                    style={{
                      flex: 1,
                      minHeight: 52,
                      borderRadius: 16,
                      borderWidth: 2,
                      borderColor: sel ? colors.brand : colors.border,
                      backgroundColor: sel ? colors.brandTertiary : colors.surfaceSecondary,
                      alignItems: "center",
                      justifyContent: "center",
                    }}
                  >
                    <Txt weight="700" color={sel ? colors.onBrandTertiary : colors.onSurface}>
                      {x.label}
                    </Txt>
                  </Pressable>
                );
              })}
            </Row>
            <Txt variant="title">الفترة المناسبة</Txt>
            <View style={{ gap: 8 }}>
              {SLOTS.map((s) => {
                const sel = d.slot === s.id;
                return (
                  <Pressable
                    key={s.id}
                    testID={`wizard-slot-${s.id}`}
                    onPress={() => set({ slot: s.id })}
                    style={{
                      minHeight: 52,
                      paddingHorizontal: 16,
                      borderRadius: 16,
                      borderWidth: 2,
                      borderColor: sel ? colors.brand : colors.border,
                      backgroundColor: sel ? colors.brandTertiary : colors.surfaceSecondary,
                      flexDirection: "row-reverse",
                      alignItems: "center",
                      justifyContent: "space-between",
                    }}
                  >
                    <Txt weight="700" color={sel ? colors.onBrandTertiary : colors.onSurface}>
                      {s.label}
                    </Txt>
                    {sel ? <Icon name="checkmark-circle" size={20} color={colors.brand} /> : null}
                  </Pressable>
                );
              })}
            </View>
          </>
        ) : null}

        {step === 3 ? (
          <>
            <Card testID="wizard-summary-card" style={{ gap: 10 }}>
              <SectionTitle title="ملخص طلبك" />
              <Row style={{ justifyContent: "space-between" }}>
                <Txt color={colors.muted}>القسم</Txt>
                <Txt weight="700">
                  {curCat?.name}
                  {curSrv ? ` • ${curSrv.name}` : ""}
                </Txt>
              </Row>
              <Row style={{ justifyContent: "space-between" }}>
                <Txt color={colors.muted}>الاستعجال</Txt>
                <Badge label={d.urgency === "urgent" ? "عاجل" : "عادي"} tone={d.urgency === "urgent" ? "warning" : "neutral"} />
              </Row>
              <Row style={{ justifyContent: "space-between" }}>
                <Txt color={colors.muted}>المكان</Txt>
                <Txt weight="700">
                  {d.area} — {d.address}
                </Txt>
              </Row>
              <Row style={{ justifyContent: "space-between" }}>
                <Txt color={colors.muted}>الموعد</Txt>
                <Txt weight="700">
                  {d.day === "today" ? "النهارده" : "بكرة"} • {SLOTS.find((s) => s.id === d.slot)?.label}
                </Txt>
              </Row>
              <View style={{ height: 1, backgroundColor: colors.divider }} />
              <Txt color={colors.onSurfaceSecondary}>{d.description}</Txt>
            </Card>

            <Txt variant="title">طريقة الدفع</Txt>
            <View style={{ gap: 8 }}>
              <Pressable
                testID="wizard-payment-cash"
                onPress={() => set({ payment_method: "cash" })}
                style={{
                  padding: 16,
                  borderRadius: 16,
                  borderWidth: 2,
                  borderColor: d.payment_method === "cash" ? colors.brand : colors.border,
                  backgroundColor: d.payment_method === "cash" ? colors.brandTertiary : colors.surfaceSecondary,
                  flexDirection: "row-reverse",
                  alignItems: "center",
                  gap: 12,
                }}
              >
                <Icon name="cash" size={24} color={colors.brand} />
                <View style={{ flex: 1 }}>
                  <Txt weight="700">كاش للفني بعد إتمام الخدمة</Txt>
                  <Txt variant="caption" color={colors.muted}>
                    ادفع المبلغ المتفق عليه في العرض مباشرة بعد التأكد من الشغل
                  </Txt>
                </View>
                <Badge label="مفعل" tone="success" />
              </Pressable>

              <Pressable
                testID="wizard-payment-online"
                disabled={!pay.data?.online_enabled}
                onPress={() => pay.data?.online_enabled && set({ payment_method: "online" })}
                style={{
                  padding: 16,
                  borderRadius: 16,
                  borderWidth: 2,
                  borderColor: d.payment_method === "online" ? colors.brand : colors.border,
                  backgroundColor: colors.surfaceSecondary,
                  opacity: pay.data?.online_enabled ? 1 : 0.6,
                  flexDirection: "row-reverse",
                  alignItems: "center",
                  gap: 12,
                }}
              >
                <Icon name="card" size={24} color={colors.muted} />
                <View style={{ flex: 1 }}>
                  <Txt weight="700">دفع إلكتروني (بطاقة / محفظة)</Txt>
                  <Txt variant="caption" color={colors.muted}>
                    فودافون كاش، إنستاباي، فيزا وميزة
                  </Txt>
                </View>
                <Badge label={pay.data?.online_enabled ? "متاح" : "قريبًا"} tone={pay.data?.online_enabled ? "success" : "neutral"} />
              </Pressable>
            </View>
          </>
        ) : null}

        <Row gap={12}>
          {step > 0 ? <Btn testID="wizard-back-button" variant="outline" label="السابق" onPress={() => setStep(step - 1)} style={{ flex: 1 }} /> : null}
          {step < 3 ? (
            <Btn testID="wizard-next-button" label="التالي" icon="arrow-back" disabled={!canNext} onPress={() => setStep(step + 1)} style={{ flex: 2 }} />
          ) : (
            <Btn testID="wizard-submit-button" label="إرسال الطلب واستقبال العروض" icon="send" loading={submitting} onPress={submit} style={{ flex: 2 }} />
          )}
        </Row>
      </KeyboardAwareScrollView>
    </View>
  );
}