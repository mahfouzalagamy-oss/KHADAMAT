import { useEffect, useState } from "react";
import { Pressable, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { KeyboardAwareScrollView } from "react-native-keyboard-controller";
import { useQueryClient } from "@tanstack/react-query";
import { api, useApi } from "@/src/api";
import { Badge, Btn, Card, Field, Header, Icon, IconName, Loading, Row, SectionTitle, Txt, useToast } from "@/src/ui";
import { useTheme } from "@/src/theme";
import { dateTimeFmt, egp, IDENTITY } from "@/src/format";

export default function TechProfile() {
  const { colors } = useTheme();
  const insets = useSafeAreaInsets();
  const toast = useToast();
  const qc = useQueryClient();
  const dash = useApi<any>("/tech/dashboard");
  const cat = useApi<any>("/catalog");
  const plans = useApi<any[]>("/plans");
  const invoices = useApi<any[]>("/tech/invoices");
  const pay = useApi<any>("/payments/config");
  const p = dash.data?.profile;
  const [cats, setCats] = useState<string[]>([]);
  const [bio, setBio] = useState("");
  const [idName, setIdName] = useState("");
  const [nid, setNid] = useState("");
  const [busy, setBusy] = useState<string | null>(null);

  useEffect(() => {
    if (p) {
      setCats(p.categories);
      setBio(p.bio);
    }
  }, [p]);

  const act = async (key: string, fn: () => Promise<any>, ok: string) => {
    setBusy(key);
    try {
      await fn();
      toast(ok);
      qc.invalidateQueries();
    } catch (e: any) {
      toast(e.message, "error");
    } finally {
      setBusy(null);
    }
  };

  if (!p)
    return (
      <View style={{ flex: 1, backgroundColor: colors.surface }}>
        <Header title="ملفي كفني" />
        <Loading />
      </View>
    );

  const unpaid = invoices.data?.find((i) => i.status === "unpaid");

  return (
    <View style={{ flex: 1, backgroundColor: colors.surface }}>
      <Header title="ملفي كفني" subtitle="الهوية • التخصصات • الاشتراك" />
      <KeyboardAwareScrollView bottomOffset={24} keyboardShouldPersistTaps="handled" contentContainerStyle={{ padding: 16, gap: 16, paddingBottom: insets.bottom + 32 }}>
        <Card testID="tech-identity-card" style={{ gap: 12 }}>
          <SectionTitle title="توثيق الهوية" action={<Badge testID="tech-identity-status" label={IDENTITY[p.identity_status].label} tone={IDENTITY[p.identity_status].tone} />} />
          {p.identity_status === "approved" ? (
            <Row gap={8}>
              <Icon name="shield-checkmark" size={22} color={colors.brand} />
              <Txt style={{ flex: 1 }}>هويتك موثقة، العملاء بيشوفوا علامة «فني موثق» على عروضك.</Txt>
            </Row>
          ) : p.identity_status === "pending" ? (
            <Txt color={colors.onSurfaceSecondary}>بياناتك تحت المراجعة من فريق خدمات. هيوصلك إشعار بالنتيجة.</Txt>
          ) : (
            <>
              {p.identity_status === "rejected" && p.review_note ? (
                <Txt color={colors.error}>سبب الرفض: {p.review_note}</Txt>
              ) : null}
              <Txt variant="caption" color={colors.muted}>
                أدخل بياناتك كما في بطاقة الرقم القومي. البيانات بتراجعها الإدارة فقط.
              </Txt>
              <Field testID="tech-identity-name-input" label="الاسم رباعي" value={idName} onChangeText={setIdName} />
              <Field testID="tech-identity-nid-input" label="الرقم القومي (14 رقم)" keyboardType="number-pad" maxLength={14} value={nid} onChangeText={setNid} />
              <Btn
                testID="tech-identity-submit-button"
                label="إرسال للمراجعة"
                icon="send"
                disabled={idName.trim().length < 5 || !/^[23]\d{13}$/.test(nid)}
                loading={busy === "id"}
                onPress={() => act("id", () => api("/tech/identity", { body: { full_name: idName, national_id: nid } }), "تم إرسال بياناتك للمراجعة")}
              />
            </>
          )}
        </Card>

        <Card testID="tech-specialties-card" style={{ gap: 12 }}>
          <SectionTitle title="تخصصاتك" />
          <View style={{ flexDirection: "row-reverse", flexWrap: "wrap", gap: 8 }}>
            {(cat.data?.categories ?? []).map((c: any) => {
              const sel = cats.includes(c.id);
              return (
                <Pressable
                  key={c.id}
                  testID={`tech-specialty-${c.id}`}
                  onPress={() => setCats(sel ? cats.filter((x) => x !== c.id) : [...cats, c.id])}
                  style={{
                    width: "31%",
                    flexGrow: 1,
                    paddingVertical: 12,
                    borderRadius: 16,
                    alignItems: "center",
                    gap: 4,
                    borderWidth: 2,
                    borderColor: sel ? colors.brand : colors.border,
                    backgroundColor: sel ? colors.brandTertiary : colors.surfaceSecondary,
                  }}
                >
                  <Icon name={c.icon as IconName} size={22} color={sel ? colors.brand : colors.muted} />
                  <Txt variant="caption" weight="700" center>
                    {c.name}
                  </Txt>
                </Pressable>
              );
            })}
          </View>
          <Field testID="tech-bio-input" label="نبذة عنك" placeholder="مثال: خبرة 10 سنين في السباكة" value={bio} onChangeText={setBio} />
          <Btn
            testID="tech-profile-save-button"
            label="حفظ التخصصات"
            icon="save"
            disabled={!cats.length}
            loading={busy === "prof"}
            onPress={() => act("prof", () => api("/tech/profile", { method: "PUT", body: { categories: cats, bio, online: p.online } }), "تم حفظ ملفك")}
          />
        </Card>

        <Card testID="tech-subscription-card" style={{ gap: 12 }}>
          <SectionTitle
            title="الاشتراك"
            action={<Badge label={dash.data.subscription_active ? `ساري حتى ${p.subscription_until.slice(0, 10)}` : "غير مفعل"} tone={dash.data.subscription_active ? "success" : "error"} />}
          />
          <Txt variant="caption" color={colors.muted}>
            الاشتراك بيخليك تستقبل الطلبات وتقدم عروض بلا عمولة على الشغل.
          </Txt>
          {(plans.data ?? []).map((pl) => (
            <Row key={pl.id} gap={12} style={{ padding: 12, borderRadius: 16, backgroundColor: colors.surfaceTertiary }}>
              <View style={{ flex: 1 }}>
                <Txt variant="title">اشتراك {pl.name}</Txt>
                <Txt variant="caption" color={colors.muted}>
                  {pl.days} يوم
                </Txt>
              </View>
              <Txt variant="title" color={colors.brand}>
                {egp(pl.price)}
              </Txt>
              <Btn
                testID={`tech-subscribe-${pl.id}`}
                small
                label="اشترك"
                disabled={!!unpaid}
                loading={busy === pl.id}
                onPress={() => act(pl.id, () => api("/tech/subscribe", { body: { plan: pl.id } }), "تم إصدار الفاتورة")}
              />
            </Row>
          ))}
          {unpaid ? (
            <View style={{ gap: 8, padding: 12, borderRadius: 16, backgroundColor: colors.warningSoft }} testID="tech-unpaid-invoice">
              <Txt weight="700" color={colors.onWarningSoft}>
                فاتورة {unpaid.number} بقيمة {egp(unpaid.amount)} بانتظار الدفع
              </Txt>
              <Txt variant="caption" color={colors.onWarningSoft}>
                ادفع نقدًا لمندوب خدمات، والإدارة هتفعل اشتراكك فور التأكيد.
              </Txt>
              <Btn
                testID="tech-invoice-pay-online-button"
                small
                variant="outline"
                icon="card"
                label={pay.data?.online_enabled ? "ادفع إلكترونيًا" : "الدفع الإلكتروني قريبًا"}
                disabled={!pay.data?.online_enabled}
                onPress={() => act("pay", () => api("/payments/checkout", { body: { kind: "invoice", ref_id: unpaid.id } }), "")}
              />
            </View>
          ) : null}
        </Card>

        <Card testID="tech-invoices-card" style={{ gap: 8 }}>
          <SectionTitle title="فواتيري" />
          {!invoices.data?.length ? (
            <Txt color={colors.muted}>لا توجد فواتير</Txt>
          ) : (
            invoices.data.map((inv) => (
              <Row key={inv.id} style={{ justifyContent: "space-between", paddingVertical: 8, borderBottomWidth: 1, borderBottomColor: colors.divider }}>
                <View>
                  <Txt weight="700">{inv.number}</Txt>
                  <Txt variant="caption" color={colors.muted}>
                    {inv.plan_name} • {dateTimeFmt(inv.created_at)}
                  </Txt>
                </View>
                <View style={{ alignItems: "flex-start", gap: 2 }}>
                  <Txt weight="700" color={colors.brand}>
                    {egp(inv.amount)}
                  </Txt>
                  <Badge label={inv.status === "paid" ? "مدفوعة" : "غير مدفوعة"} tone={inv.status === "paid" ? "success" : "warning"} />
                </View>
              </Row>
            ))
          )}
        </Card>
      </KeyboardAwareScrollView>
    </View>
  );
}