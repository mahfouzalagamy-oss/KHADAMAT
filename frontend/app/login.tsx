import { useState } from "react";
import { Pressable, View } from "react-native";
import { useRouter } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { KeyboardAwareScrollView } from "react-native-keyboard-controller";
import { LinearGradient } from "expo-linear-gradient";
import { api } from "@/src/api";
import { useAuth, User } from "@/src/auth";
import { Btn, Card, Field, Icon, Row, Txt, useToast } from "@/src/ui";
import { useTheme } from "@/src/theme";
import { phoneFmt } from "@/src/format";

const DEMO = [
  { label: "عميل", phone: "01000000004" },
  { label: "فني", phone: "01000000003" },
  { label: "شركة", phone: "01000000002" },
  { label: "إدارة", phone: "01000000001" },
];

export default function Login() {
  const { colors } = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const toast = useToast();
  const { signIn } = useAuth();
  const [step, setStep] = useState<"phone" | "otp">("phone");
  const [phone, setPhone] = useState("");
  const [normalized, setNormalized] = useState("");
  const [isNew, setIsNew] = useState(false);
  const [otp, setOtp] = useState("");
  const [name, setName] = useState("");
  const [role, setRole] = useState<"customer" | "technician">("customer");
  const [busy, setBusy] = useState(false);
  const [demoCode, setDemoCode] = useState("");

  const sendOtp = async () => {
    setBusy(true);
    try {
      const r = await api<{ phone: string; is_new: boolean; demo_code: string }>("/auth/request-otp", {
        body: { phone },
      });
      setNormalized(r.phone);
      setIsNew(r.is_new);
      setDemoCode(r.demo_code);
      setStep("otp");
    } catch (e: any) {
      toast(e.message, "error");
    } finally {
      setBusy(false);
    }
  };

  const verify = async () => {
    if (isNew && name.trim().length < 2) return toast("اكتب اسمك من فضلك", "error");
    setBusy(true);
    try {
      const r = await api<{ token: string; user: User }>("/auth/verify-otp", {
        body: { phone: normalized, otp, role, name },
      });
      await signIn(r.token, r.user);
      router.replace("/(tabs)");
    } catch (e: any) {
      toast(e.message, "error");
    } finally {
      setBusy(false);
    }
  };

  return (
    <View style={{ flex: 1, backgroundColor: colors.surface }}>
      <KeyboardAwareScrollView
        bottomOffset={24}
        keyboardShouldPersistTaps="handled"
        contentContainerStyle={{ paddingBottom: insets.bottom + 24 }}
      >
        <LinearGradient
          colors={[colors.brandDeep, colors.brand]}
          style={{ paddingTop: insets.top + 32, paddingHorizontal: 24, paddingBottom: 56, gap: 8 }}
        >
          <View
            style={{
              width: 64,
              height: 64,
              borderRadius: 20,
              backgroundColor: colors.brandSecondary,
              alignItems: "center",
              justifyContent: "center",
              alignSelf: "flex-end",
            }}
          >
            <Icon name="construct" size={32} color={colors.onBrandSecondary} />
          </View>
          <Txt variant="display" color={colors.onBrand}>
            خدمات
          </Txt>
          <Txt variant="title" color={colors.brandTertiary} weight="500">
            كل خدمات بيتك في المنصورة، بضغطة واحدة
          </Txt>
        </LinearGradient>

        <View style={{ paddingHorizontal: 16, marginTop: -32, gap: 16 }}>
          <Card style={{ gap: 16 }}>
            {step === "phone" ? (
              <>
                <Txt variant="h2">سجّل برقم موبايلك</Txt>
                <Field
                  testID="login-phone-input"
                  label="رقم الموبايل"
                  placeholder="01X XXXX XXXX"
                  keyboardType="phone-pad"
                  value={phone}
                  onChangeText={setPhone}
                  maxLength={14}
                />
                <Btn
                  testID="login-send-otp-button"
                  label="إرسال كود التأكيد"
                  icon="chatbubble-ellipses"
                  loading={busy}
                  disabled={phone.replace(/\D/g, "").length < 10}
                  onPress={sendOtp}
                />
              </>
            ) : (
              <>
                <Row style={{ justifyContent: "space-between" }}>
                  <Txt variant="h2">أدخل الكود</Txt>
                  <Pressable testID="login-change-phone-button" onPress={() => setStep("phone")}>
                    <Txt color={colors.brand} weight="700">
                      تغيير الرقم
                    </Txt>
                  </Pressable>
                </Row>
                <Txt color={colors.muted}>أرسلنا كود من 6 أرقام إلى {phoneFmt(normalized)}</Txt>
                <View
                  testID="login-demo-code-hint"
                  style={{ backgroundColor: colors.warningSoft, borderRadius: 12, padding: 12 }}
                >
                  <Txt variant="caption" color={colors.onWarningSoft} weight="700">
                    نسخة تجريبية: الرسائل النصية غير مفعلة بعد. الكود هو {demoCode}
                  </Txt>
                </View>
                <Field
                  testID="login-otp-input"
                  placeholder="______"
                  keyboardType="number-pad"
                  maxLength={6}
                  value={otp}
                  onChangeText={setOtp}
                  style={{ textAlign: "center", fontSize: 24, letterSpacing: 8 }}
                />
                {isNew ? (
                  <>
                    <Field testID="login-name-input" label="اسمك" placeholder="مثال: أحمد محمد" value={name} onChangeText={setName} />
                    <Txt weight="500" color={colors.onSurfaceSecondary}>
                      هتستخدم التطبيق كـ
                    </Txt>
                    <Row gap={12}>
                      {(
                        [
                          { id: "customer", label: "عميل", sub: "أطلب خدمة", icon: "home" },
                          { id: "technician", label: "فني", sub: "أقدم خدماتي", icon: "construct" },
                        ] as const
                      ).map((r) => {
                        const sel = role === r.id;
                        return (
                          <Pressable
                            key={r.id}
                            testID={`login-role-${r.id}`}
                            onPress={() => setRole(r.id)}
                            style={{
                              flex: 1,
                              padding: 16,
                              borderRadius: 16,
                              borderWidth: 2,
                              borderColor: sel ? colors.brand : colors.border,
                              backgroundColor: sel ? colors.brandTertiary : colors.surfaceSecondary,
                              gap: 4,
                            }}
                          >
                            <Icon name={r.icon} size={24} color={sel ? colors.brand : colors.muted} />
                            <Txt variant="title">{r.label}</Txt>
                            <Txt variant="caption" color={colors.muted}>
                              {r.sub}
                            </Txt>
                          </Pressable>
                        );
                      })}
                    </Row>
                  </>
                ) : null}
                <Btn
                  testID="login-verify-button"
                  label={isNew ? "إنشاء الحساب" : "دخول"}
                  icon="log-in"
                  loading={busy}
                  disabled={otp.length !== 6}
                  onPress={verify}
                />
              </>
            )}
          </Card>

          {step === "phone" ? (
            <View style={{ gap: 8 }}>
              <Txt variant="caption" color={colors.muted}>
                حسابات تجريبية للمعاينة
              </Txt>
              <Row gap={8} style={{ flexWrap: "wrap" }}>
                {DEMO.map((d) => (
                  <Pressable
                    key={d.phone}
                    testID={`login-demo-${d.phone}`}
                    onPress={() => setPhone(d.phone)}
                    style={{
                      paddingHorizontal: 16,
                      height: 36,
                      borderRadius: 999,
                      justifyContent: "center",
                      backgroundColor: colors.surfaceTertiary,
                    }}
                  >
                    <Txt variant="caption" weight="700" color={colors.onSurfaceTertiary}>
                      {d.label} • {d.phone}
                    </Txt>
                  </Pressable>
                ))}
              </Row>
            </View>
          ) : null}
          <Row gap={6} style={{ justifyContent: "center" }}>
            <Icon name="shield-checkmark" size={16} color={colors.brand} />
            <Txt variant="caption" color={colors.muted}>
              فنيين موثقين • أسعار بالجنيه • دفع كاش أو إلكتروني
            </Txt>
          </Row>
        </View>
      </KeyboardAwareScrollView>
    </View>
  );
}