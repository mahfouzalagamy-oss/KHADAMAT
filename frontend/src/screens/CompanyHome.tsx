import { useState } from "react";
import { Pressable, RefreshControl, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { KeyboardAwareScrollView } from "react-native-keyboard-controller";
import { api, useApi } from "@/src/api";
import { useAuth } from "@/src/auth";
import { Badge, Btn, Card, ErrorView, Field, Icon, Loading, Row, SectionTitle, Txt, useToast } from "@/src/ui";
import { useTheme } from "@/src/theme";
import { usesNativeTabs } from "@/src/navigation";
import { egp, IDENTITY, phoneFmt } from "@/src/format";
import { RequestCard } from "@/src/components/RequestCard";

export default function CompanyHome() {
  const { colors } = useTheme();
  const insets = useSafeAreaInsets();
  const toast = useToast();
  const { user } = useAuth();
  const q = useApi<any>("/company/overview");
  const cat = useApi<any>("/catalog");
  const [adding, setAdding] = useState(false);
  const [phone, setPhone] = useState("");
  const [name, setName] = useState("");
  const [cats, setCats] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  const bottomChrome = usesNativeTabs ? insets.bottom : 0;

  const add = async () => {
    setBusy(true);
    try {
      await api("/company/technicians", { body: { phone, name, categories: cats } });
      toast("تمت إضافة الفني — يحتاج توثيق الهوية من الإدارة");
      setAdding(false);
      setPhone("");
      setName("");
      setCats([]);
      q.refetch();
    } catch (e: any) {
      toast(e.message, "error");
    } finally {
      setBusy(false);
    }
  };

  return (
    <View style={{ flex: 1, backgroundColor: colors.surface }}>
      <View style={{ paddingTop: insets.top + 8, paddingHorizontal: 16, paddingBottom: 12, backgroundColor: colors.brandDeep }}>
        <Txt variant="caption" color={colors.brandTertiary}>
          إدارة الشركة
        </Txt>
        <Txt variant="h2" color={colors.onBrand}>
          {user?.name}
        </Txt>
      </View>
      {q.isLoading ? (
        <Loading />
      ) : q.isError ? (
        <ErrorView message={(q.error as Error).message} onRetry={() => q.refetch()} />
      ) : (
        <KeyboardAwareScrollView
          bottomOffset={24}
          keyboardShouldPersistTaps="handled"
          contentContainerStyle={{ padding: 16, gap: 16, paddingBottom: bottomChrome + 24 }}
          refreshControl={<RefreshControl refreshing={q.isRefetching} onRefresh={() => q.refetch()} tintColor={colors.brand} />}
        >
          <Row gap={12}>
            <Card testID="company-revenue" style={{ flex: 1, backgroundColor: colors.brand, borderColor: colors.brand }}>
              <Txt variant="caption" color={colors.brandTertiary}>
                إيراد الشغل المنجز
              </Txt>
              <Txt variant="h2" color={colors.onBrand}>
                {egp(q.data.revenue)}
              </Txt>
            </Card>
            <Card testID="company-tech-count" style={{ flex: 1 }}>
              <Txt variant="caption" color={colors.muted}>
                الفنيين
              </Txt>
              <Txt variant="h2">{q.data.technicians.length}</Txt>
            </Card>
          </Row>

          <View style={{ gap: 12 }}>
            <SectionTitle
              title="فنيين الشركة"
              action={<Btn testID="company-add-tech-toggle" small variant="soft" icon={adding ? "close" : "person-add"} label={adding ? "إغلاق" : "إضافة فني"} onPress={() => setAdding(!adding)} />}
            />
            {adding ? (
              <Card testID="company-add-tech-form" style={{ gap: 12 }}>
                <Field testID="company-tech-name-input" label="اسم الفني" value={name} onChangeText={setName} />
                <Field testID="company-tech-phone-input" label="رقم الموبايل" keyboardType="phone-pad" placeholder="01X XXXX XXXX" value={phone} onChangeText={setPhone} />
                <Txt weight="500">التخصصات</Txt>
                <View style={{ flexDirection: "row-reverse", flexWrap: "wrap", gap: 8 }}>
                  {(cat.data?.categories ?? []).map((c: any) => {
                    const sel = cats.includes(c.id);
                    return (
                      <Pressable
                        key={c.id}
                        testID={`company-tech-cat-${c.id}`}
                        onPress={() => setCats(sel ? cats.filter((x) => x !== c.id) : [...cats, c.id])}
                        style={{
                          paddingHorizontal: 14,
                          height: 40,
                          borderRadius: 12,
                          justifyContent: "center",
                          borderWidth: 1,
                          borderColor: sel ? colors.brand : colors.border,
                          backgroundColor: sel ? colors.brandTertiary : colors.surfaceSecondary,
                        }}
                      >
                        <Txt weight="500" color={sel ? colors.onBrandTertiary : colors.onSurfaceSecondary}>
                          {c.name}
                        </Txt>
                      </Pressable>
                    );
                  })}
                </View>
                <Btn testID="company-add-tech-submit" label="إضافة" icon="checkmark" loading={busy} disabled={name.length < 2 || phone.length < 10 || !cats.length} onPress={add} />
              </Card>
            ) : null}
            {q.data.technicians.map((t: any) => (
              <Card key={t.user_id} testID={`company-tech-${t.user_id}`} style={{ gap: 4 }}>
                <Row style={{ justifyContent: "space-between" }}>
                  <Row gap={8}>
                    <Icon name="person-circle" size={28} color={colors.brand} />
                    <Txt variant="title">{t.name}</Txt>
                  </Row>
                  <Badge label={IDENTITY[t.identity_status]?.label} tone={IDENTITY[t.identity_status]?.tone} />
                </Row>
                <Txt variant="caption" color={colors.muted}>
                  {phoneFmt(t.phone)} • {t.jobs_done} شغلانة • أرباح {egp(t.earnings)}
                </Txt>
              </Card>
            ))}
          </View>

          <View style={{ gap: 12 }}>
            <SectionTitle title="شغل الشركة" />
            {q.data.jobs.length ? (
              q.data.jobs.map((r: any, i: number) => <RequestCard key={r.id} r={r} index={i} />)
            ) : (
              <Txt color={colors.muted}>لا يوجد شغل بعد</Txt>
            )}
          </View>
        </KeyboardAwareScrollView>
      )}
    </View>
  );
}