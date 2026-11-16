import { useEffect, useMemo, useRef, useState } from "react";
import { Linking, Pressable, View } from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { KeyboardAwareScrollView } from "react-native-keyboard-controller";
import Animated, { FadeIn } from "react-native-reanimated";
import * as Location from "expo-location";
import * as Haptics from "expo-haptics";
import { Image } from "expo-image";
import { api, useApi } from "@/src/api";
import { pickAndUploadImage, resolveMediaUrl } from "@/src/utils/pick-and-upload";
import { storage } from "@/src/utils/storage";
import { useOnline } from "@/src/net";
import { Badge, Btn, Card, Chip, ChipRow, Field, Header, Icon, IconName, OfflineBanner, Row, Txt, useToast } from "@/src/ui";
import { useTheme } from "@/src/theme";
import { dayName, egp, monthName, timeFmt } from "@/src/format";

const DRAFT_KEY = "request_draft";
const STEPS = ["المشكلة", "الموقع", "الموعد", "التأكيد"];
const SLOTS = [9, 11, 13, 15, 17, 19, 21];

type Draft = {
  category_id: string;
  service_id: string;
  description: string;
  urgency: "normal" | "urgent";
  area: string;
  address: string;
  lat: number | null;
  lng: number | null;
  date: string;
  hour: number | null;
  payment_method: "cash" | "online";
  photos: string[];
};

const EMPTY: Draft = {
  category_id: "",
  service_id: "",
  description: "",
  urgency: "normal",
  area: "",
  address: "",
  lat: null,
  lng: null,
  date: "",
  hour: null,
  payment_method: "cash",
  photos: [],
};

const ymd = (d: Date) => `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;

export default function NewRequest() {
  const params = useLocalSearchParams<{ category?: string; service?: string }>();
  const { colors } = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const toast = useToast();
  const online = useOnline();
  const catalog = useApi<any>("/catalog");
  const payCfg = useApi<any>("/payments/config");
  const [step, setStep] = useState(0);
  const [d, setD] = useState<Draft>(EMPTY);
  const [restored, setRestored] = useState(false);
  const [savedAt, setSavedAt] = useState<number | null>(null);
  const [ai, setAi] = useState<any>(null);
  const [aiBusy, setAiBusy] = useState(false);
  const [uploadingPhoto, setUploadingPhoto] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [loc, setLoc] = useState<"idle" | "explain" | "loading" | "denied" | "blocked">("idle");
  const saveTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const category = useApi<any>(d.category_id ? `/catalog/${d.category_id}` : null);

  useEffect(() => {
    (async () => {
      const raw = await storage.getItem(DRAFT_KEY, null);
      let base = EMPTY;
      if (typeof raw === "string") {
        try {
          base = { ...EMPTY, ...JSON.parse(raw) };
        } catch {}
      }
      if (params.category) base = { ...base, category_id: params.category, service_id: params.service ?? "" };
      setD(base);
      setRestored(true);
    })();
  }, [params.category, params.service]);

  useEffect(() => {
    if (!restored) return;
    if (saveTimer.current) clearTimeout(saveTimer.current);
    saveTimer.current = setTimeout(async () => {
      if (await storage.setItem(DRAFT_KEY, JSON.stringify(d))) setSavedAt(Date.now());
    }, 500);
  }, [d, restored]);

  const set = (patch: Partial<Draft>) => setD((p) => ({ ...p, ...patch }));
  const days = useMemo(
    () =>
      Array.from({ length: 10 }, (_, i) => {
        const x = new Date();
        x.setDate(x.getDate() + i);
        return x;
      }),
    [],
  );
  const service = category.data?.services?.find((s: any) => s.id === d.service_id);

  const slotDisabled = (h: number) => {
    if (d.date !== ymd(new Date())) return false;
    return h <= new Date().getHours() + 1;
  };

  const runAi = async () => {
    if (!online) return toast("المساعد الذكي محتاج إنترنت، وصفك محفوظ كمسودة", "info");
    setAiBusy(true);
    try {
      const r = await api("/ai/describe", { body: { text: d.description, category_id: d.category_id || null } });
      setAi(r);
      set({ urgency: r.urgency, category_id: d.category_id || r.category_id });
    } catch (e: any) {
      toast(e.message, "error");
    } finally {
      setAiBusy(false);
    }
  };

  const useMyLocation = async () => {
    setLoc("loading");
    let perm = await Location.getForegroundPermissionsAsync();
    if (perm.status !== "granted") {
      if (!perm.canAskAgain) return setLoc("blocked");
      perm = await Location.requestForegroundPermissionsAsync();
    }
    if (perm.status !== "granted") return setLoc(perm.canAskAgain ? "denied" : "blocked");
    try {
      const pos = await Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.Balanced });
      set({ lat: pos.coords.latitude, lng: pos.coords.longitude });
      setLoc("idle");
      toast("تم تحديد موقعك");
    } catch {
      setLoc("idle");
      toast("تعذر تحديد الموقع، اكتب العنوان يدويًا", "error");
    }
  };

  const canNext = [
    !!d.category_id && d.description.trim().length >= 3,
    !!d.area && d.address.trim().length >= 3,
    !!d.date && d.hour != null,
    true,
  ][step];

  const submit = async () => {
    if (!online) return toast("أنت غير متصل. طلبك محفوظ كمسودة، أرسله لما يرجع النت", "info");
    const [y, m, day] = d.date.split("-").map(Number);
    const at = new Date(y, m - 1, day, d.hour ?? 9, 0, 0);
    setSubmitting(true);
    try {
      const r = await api("/requests", {
        body: {
          category_id: d.category_id,
          service_id: d.service_id || null,
          description: d.description,
          urgency: d.urgency,
          area: d.area,
          address: d.address,
          lat: d.lat,
          lng: d.lng,
          scheduled_at: at.toISOString(),
          payment_method: d.payment_method,
          photos: d.photos,
        },
      });
      await storage.removeItem(DRAFT_KEY);
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
      toast("تم إرسال طلبك للفنيين");
      router.replace(`/request/${r.id}`);
    } catch (e: any) {
      toast(e.message, "error");
    } finally {
      setSubmitting(false);
    }
  };

  const catName = catalog.data?.categories?.find((c: any) => c.id === d.category_id)?.name;

  return (
    <View style={{ flex: 1, backgroundColor: colors.surface }}>
      <Header
        title="طلب خدمة جديد"
        subtitle={catName ? `${catName}${service ? " • " + service.name : ""}` : "المنصورة، الدقهلية"}
        right={
          savedAt ? (
            <Badge testID="draft-saved-badge" label="مسودة محفوظة" tone="muted" icon="save" />
          ) : null
        }
      />
      {!online ? <OfflineBanner text="أنت غير متصل — كل اللي بتكتبه محفوظ على جهازك كمسودة" /> : null}

      <Row gap={6} style={{ paddingHorizontal: 16, paddingVertical: 12 }}>
        {STEPS.map((s, i) => (
          <View key={s} style={{ flex: 1, gap: 4 }} testID={`wizard-step-${i}`}>
            <View style={{ height: 6, borderRadius: 3, backgroundColor: i <= step ? colors.brand : colors.border }} />
            <Txt variant="caption" weight={i === step ? "700" : "400"} color={i <= step ? colors.brand : colors.muted}>
              {s}
            </Txt>
          </View>
        ))}
      </Row>

      <KeyboardAwareScrollView
        bottomOffset={110}
        keyboardShouldPersistTaps="handled"
        contentContainerStyle={{ paddingBottom: 120 + insets.bottom, gap: 16 }}
      >
        {step === 0 ? (
          <Animated.View entering={FadeIn} style={{ gap: 16 }}>
            <View>
              <Txt variant="title" style={{ paddingHorizontal: 16 }}>
                نوع الخدمة
              </Txt>

            {(params.category_id || d.category_id) ? (
              <Card
                testID={`wizard-category-${params.category_id || d.category_id}`}
                style={{ backgroundColor: colors.brandTertiary, borderColor: colors.brand, borderWidth: 2 }}
              >
                <Row style={{ justifyContent: "space-between" }}>
                  <Row gap={10}>
                    <Icon name={(curCat?.icon || "construct") as IconName} size={22} color={colors.brand} />
                    <View>
                      <Txt weight="700" color={colors.onBrandTertiary}>
                        {curCat?.name ?? "الخدمة المختارة"}{curSrv ? ` • ${curSrv.name}` : ""}
                      </Txt>
                      {curSrv ? (
                        <Txt variant="caption" color={colors.brand}>
                          السعر الاسترشادي: {egp(curSrv.min)} - {egp(curSrv.max)}
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
                    selected={d.category_id === c.id}
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
                onChangeText={(t) => set({ description: t })}
                maxLength={2000}
              />
              <Btn
                testID="wizard-ai-button"
                label="رتّب الوصف بالذكاء الاصطناعي"
                icon="sparkles"
                variant="secondary"
                loading={aiBusy}
                disabled={d.description.trim().length < 3}
                onPress={runAi}
              />
              {ai ? (
                <Animated.View entering={FadeIn}>
                  <Card testID="wizard-ai-result" style={{ gap: 12, backgroundColor: colors.surfaceTertiary, borderColor: colors.brandTertiary }}>
                    <Row style={{ justifyContent: "space-between" }}>
                      <Row gap={6}>
                        <Icon name="sparkles" size={18} color={colors.brand} />
                        <Txt variant="title" color={colors.onSurfaceTertiary}>
                          اقتراح المساعد
                        </Txt>
                      </Row>
                      <Badge label={ai.urgency === "urgent" ? "عاجل" : "عادي"} tone={ai.urgency === "urgent" ? "error" : "success"} />
                    </Row>
                    <Txt color={colors.onSurfaceTertiary}>{ai.refined_description}</Txt>
                    <Row gap={8} style={{ flexWrap: "wrap" }}>
                      <Badge label={`القسم: ${ai.category_name}`} tone="brand" />
                      {ai.price_max ? <Badge label={`تقدير: ${ai.price_min} - ${egp(ai.price_max)}`} tone="info" /> : null}
                    </Row>
                    {ai.questions?.length ? (
                      <View style={{ gap: 4 }}>
                        <Txt variant="caption" weight="700" color={colors.muted}>
                          ممكن تضيف في وصفك:
                        </Txt>
                        {ai.questions.map((q: string) => (
                          <Txt key={q} variant="caption" color={colors.onSurfaceTertiary}>
                            • {q}
                          </Txt>
                        ))}
                      </View>
                    ) : null}
                    {ai.tips ? (
                      <Row gap={6}>
                        <Icon name="warning" size={16} color={colors.warning} />
                        <Txt variant="caption" style={{ flex: 1 }}>
                          {ai.tips}
                        </Txt>
                      </Row>
                    ) : null}
                    <Row gap={8}>
                      <Btn
                        testID="wizard-ai-apply-button"
                        small
                        label="استخدم الوصف ده"
                        icon="checkmark"
                        style={{ flex: 1 }}
                        onPress={() => {
                          set({ description: ai.refined_description, category_id: ai.category_id });
                          setAi(null);
                        }}
                      />
                      <Btn testID="wizard-ai-dismiss-button" small variant="outline" label="تجاهل" onPress={() => setAi(null)} />
                    </Row>
                  </Card>
                </Animated.View>
              ) : null}
              <Txt variant="title">صور المشكلة (اختياري)</Txt>
              <Row gap={8} style={{ flexWrap: "wrap" }}>
                {(d.photos ?? []).map((u, idx) => (
                  <Pressable
                    key={u}
                    testID={`wizard-photo-${idx}`}
                    onPress={() => set({ photos: d.photos.filter((x) => x !== u) })}
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
                    ["normal", "عادي", "time"],
                    ["urgent", "عاجل", "flash"],
                  ] as const
                ).map(([id, label, icon]) => (
                  <Pressable
                    key={id}
                    testID={`wizard-urgency-${id}`}
                    onPress={() => set({ urgency: id })}
                    style={{
                      flex: 1,
                      height: 52,
                      borderRadius: 16,
                      borderWidth: 2,
                      borderColor: d.urgency === id ? colors.brand : colors.border,
                      backgroundColor: d.urgency === id ? colors.brandTertiary : colors.surfaceSecondary,
                      flexDirection: "row-reverse",
                      alignItems: "center",
                      justifyContent: "center",
                      gap: 8,
                    }}
                  >
                    <Icon name={icon} size={18} color={d.urgency === id ? colors.brand : colors.muted} />
                    <Txt weight="700">{label}</Txt>
                  </Pressable>
                ))}
              </Row>
            </View>
          </Animated.View>
        ) : null}

        {step === 1 ? (
          <Animated.View entering={FadeIn} style={{ gap: 12 }}>
            <Txt variant="title" style={{ paddingHorizontal: 16 }}>
              المنطقة في المنصورة
            </Txt>
            <ChipRow testID="wizard-area-row">
              {(catalog.data?.areas ?? []).map((a: string, i: number) => (
                <Chip key={a} testID={`wizard-area-${i}`} label={a} selected={d.area === a} onPress={() => set({ area: a })} />
              ))}
            </ChipRow>
            <View style={{ paddingHorizontal: 16, gap: 12 }}>
              <Field
                testID="wizard-address-input"
                label="العنوان بالتفصيل"
                placeholder="الشارع، رقم العمارة، الدور، علامة مميزة"
                value={d.address}
                onChangeText={(t) => set({ address: t })}
                multiline
                style={{ minHeight: 88 }}
              />
              <Card style={{ gap: 12 }}>
                <Row gap={12}>
                  <View style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: colors.brandTertiary, alignItems: "center", justifyContent: "center" }}>
                    <Icon name="navigate" size={22} color={colors.brand} />
                  </View>
                  <View style={{ flex: 1 }}>
                    <Txt weight="700">حدد موقعك على الخريطة</Txt>
                    <Txt variant="caption" color={colors.muted}>
                      {d.lat != null ? `تم التحديد: ${d.lat.toFixed(4)}, ${d.lng?.toFixed(4)}` : "اختياري — يساعد الفني يوصلك أسرع"}
                    </Txt>
                  </View>
                </Row>
                {loc === "explain" ? (
                  <View style={{ gap: 8 }} testID="location-explain">
                    <Txt variant="caption" color={colors.onSurfaceSecondary}>
                      هنستخدم موقعك مرة واحدة بس عشان الفني يوصل لباب بيتك بدقة. مش بنتابع موقعك بعد كده.
                    </Txt>
                    <Row gap={8}>
                      <Btn testID="location-allow-button" small label="سماح" icon="checkmark" onPress={useMyLocation} style={{ flex: 1 }} />
                      <Btn testID="location-cancel-button" small variant="outline" label="لاحقًا" onPress={() => setLoc("idle")} />
                    </Row>
                  </View>
                ) : loc === "denied" ? (
                  <View style={{ gap: 8 }}>
                    <Txt variant="caption" color={colors.onErrorSoft}>
                      لم يتم السماح بالموقع. تقدر تكمل بالعنوان المكتوب أو تحاول تاني.
                    </Txt>
                    <Btn testID="location-retry-button" small variant="soft" label="حاول مرة أخرى" onPress={useMyLocation} />
                  </View>
                ) : loc === "blocked" ? (
                  <View style={{ gap: 8 }}>
                    <Txt variant="caption" color={colors.onErrorSoft}>
                      إذن الموقع مقفول. افتح الإعدادات وفعّله، أو كمل بالعنوان المكتوب.
                    </Txt>
                    <Btn testID="location-settings-button" small variant="soft" icon="settings" label="افتح الإعدادات" onPress={() => Linking.openSettings()} />
                  </View>
                ) : (
                  <Row gap={8}>
                    <Btn
                      testID="location-use-current-button"
                      small
                      variant="soft"
                      icon="locate"
                      label={d.lat != null ? "تحديث الموقع" : "استخدم موقعي الحالي"}
                      loading={loc === "loading"}
                      onPress={() => setLoc("explain")}
                      style={{ flex: 1 }}
                    />
                    {d.lat != null ? (
                      <Btn
                        testID="location-open-map-button"
                        small
                        variant="outline"
                        icon="map"
                        label="الخريطة"
                        onPress={() => Linking.openURL(`https://www.google.com/maps/search/?api=1&query=${d.lat},${d.lng}`)}
                      />
                    ) : null}
                  </Row>
                )}
              </Card>
            </View>
          </Animated.View>
        ) : null}

        {step === 2 ? (
          <Animated.View entering={FadeIn} style={{ gap: 12 }}>
            <Txt variant="title" style={{ paddingHorizontal: 16 }}>
              اختار اليوم
            </Txt>
            <ChipRow testID="wizard-date-row">
              {days.map((x, i) => {
                const sel = d.date === ymd(x);
                return (
                  <Pressable
                    key={ymd(x)}
                    testID={`wizard-date-${i}`}
                    onPress={() => set({ date: ymd(x), hour: null })}
                    style={{
                      width: 64,
                      height: 48,
                      borderRadius: 16,
                      alignItems: "center",
                      justifyContent: "center",
                      backgroundColor: sel ? colors.brand : colors.surfaceSecondary,
                      borderWidth: 1,
                      borderColor: sel ? colors.brand : colors.border,
                    }}
                  >
                    <Txt variant="caption" center color={sel ? colors.onBrand : colors.muted} style={{ lineHeight: 16 }}>
                      {i === 0 ? "النهارده" : i === 1 ? "بكره" : dayName(x)}
                    </Txt>
                    <Txt weight="700" center color={sel ? colors.onBrand : colors.onSurface} style={{ lineHeight: 20 }}>
                      {x.getDate()} {monthName(x).slice(0, 3)}
                    </Txt>
                  </Pressable>
                );
              })}
            </ChipRow>
            <View style={{ paddingHorizontal: 16, gap: 12 }}>
              <Txt variant="title">اختار الوقت</Txt>
              {!d.date ? (
                <Txt color={colors.muted}>اختار اليوم الأول</Txt>
              ) : (
                <View style={{ flexDirection: "row-reverse", flexWrap: "wrap", gap: 8 }}>
                  {SLOTS.map((h) => {
                    const dis = slotDisabled(h);
                    const sel = d.hour === h;
                    const t = new Date();
                    t.setHours(h, 0, 0, 0);
                    return (
                      <Pressable
                        key={h}
                        testID={`wizard-slot-${h}`}
                        disabled={dis}
                        onPress={() => set({ hour: h })}
                        style={{
                          width: "31%",
                          height: 48,
                          borderRadius: 999,
                          alignItems: "center",
                          justifyContent: "center",
                          backgroundColor: sel ? colors.brandSecondary : colors.surfaceSecondary,
                          borderWidth: 1,
                          borderColor: sel ? colors.brandSecondary : colors.border,
                          opacity: dis ? 0.35 : 1,
                        }}
                      >
                        <Txt weight="700" center color={sel ? colors.onBrandSecondary : colors.onSurface}>
                          {timeFmt(t)}
                        </Txt>
                      </Pressable>
                    );
                  })}
                </View>
              )}
              {d.date && SLOTS.every(slotDisabled) ? (
                <Txt color={colors.muted}>مفيش مواعيد متاحة النهارده، اختار يوم تاني</Txt>
              ) : null}
            </View>
          </Animated.View>
        ) : null}

        {step === 3 ? (
          <Animated.View entering={FadeIn} style={{ paddingHorizontal: 16, gap: 12 }}>
            <Card style={{ gap: 12 }} testID="wizard-summary">
              {(
                [
                  ["construct", "الخدمة", `${catName ?? ""}${service ? " • " + service.name : " • مشكلة مخصصة"}`],
                  ["document-text", "الوصف", d.description],
                  ["location", "العنوان", `${d.area} — ${d.address}`],
                  [
                    "calendar",
                    "الموعد",
                    d.date
                      ? (() => {
                          const [y, m, day] = d.date.split("-").map(Number);
                          const x = new Date(y, m - 1, day, d.hour ?? 9);
                          return `${dayName(x)} ${x.getDate()} ${monthName(x)} • ${timeFmt(x)}`;
                        })()
                      : "",
                  ],
                  ["pricetag", "السعر التقديري", service ? `${service.price_min} - ${egp(service.price_max)}` : "حسب عروض الفنيين"],
                ] as const
              ).map(([icon, k, v]) => (
                <Row key={k} gap={12} style={{ alignItems: "flex-start" }}>
                  <Icon name={icon} size={20} color={colors.brand} />
                  <View style={{ flex: 1 }}>
                    <Txt variant="caption" color={colors.muted}>
                      {k}
                    </Txt>
                    <Txt weight="500">{v}</Txt>
                  </View>
                </Row>
              ))}
            </Card>
            <Txt variant="title">طريقة الدفع</Txt>
            {(
              [
                ["cash", "كاش للفني بعد الشغل", "cash", true, "بنسجل كل عملية دفع في حسابك"],
                [
                  "online",
                  "دفع إلكتروني",
                  "card",
                  !!payCfg.data?.online_enabled,
                  payCfg.data?.online_enabled ? "عبر بوابة دفع مصرية آمنة" : "متاح قريبًا بعد تفعيل بوابة الدفع",
                ],
              ] as const
            ).map(([id, label, icon, enabled, sub]) => {
              const sel = d.payment_method === id;
              return (
                <Pressable
                  key={id}
                  testID={`wizard-payment-${id}`}
                  disabled={!enabled}
                  onPress={() => set({ payment_method: id })}
                  style={{
                    padding: 16,
                    borderRadius: 20,
                    borderWidth: 2,
                    borderColor: sel ? colors.brand : colors.border,
                    backgroundColor: sel ? colors.surfaceTertiary : colors.surfaceSecondary,
                    flexDirection: "row-reverse",
                    alignItems: "center",
                    gap: 12,
                    opacity: enabled ? 1 : 0.5,
                  }}
                >
                  <Icon name={icon} size={24} color={sel ? colors.brand : colors.muted} />
                  <View style={{ flex: 1 }}>
                    <Txt weight="700">{label}</Txt>
                    <Txt variant="caption" color={colors.muted}>
                      {sub}
                    </Txt>
                  </View>
                  <Icon name={sel ? "radio-button-on" : "radio-button-off"} size={22} color={sel ? colors.brand : colors.borderStrong} />
                </Pressable>
              );
            })}
            <Row gap={6}>
              <Icon name="lock-closed" size={14} color={colors.muted} />
              <Txt variant="caption" color={colors.muted} style={{ flex: 1 }}>
                خدمات لا تخزن أي بيانات بطاقات بنكية. الدفع الإلكتروني يتم بالكامل داخل بوابة الدفع.
              </Txt>
            </Row>
          </Animated.View>
        ) : null}
      </KeyboardAwareScrollView>

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
          flexDirection: "row-reverse",
          gap: 12,
        }}
      >
        {step < 3 ? (
          <Btn testID="wizard-next-button" label="التالي" icon="arrow-back" disabled={!canNext} onPress={() => setStep(step + 1)} style={{ flex: 1 }} />
        ) : (
          <Btn testID="wizard-submit-button" label="اطلب عروض الفنيين" icon="paper-plane" loading={submitting} onPress={submit} style={{ flex: 1 }} />
        )}
        {step > 0 ? <Btn testID="wizard-back-button" label="رجوع" variant="outline" onPress={() => setStep(step - 1)} /> : null}
      </View>
    </View>
  );
}