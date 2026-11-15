import { useState } from "react";
import { ScrollView, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { useRouter } from "expo-router";
import { api, useApi } from "@/src/api";
import { useAuth } from "@/src/auth";
import { Badge, Btn, Card, Field, Icon, IconName, Row, Txt, useToast } from "@/src/ui";
import { useTheme } from "@/src/theme";
import { usesNativeTabs } from "@/src/navigation";
import { phoneFmt, ROLE_AR } from "@/src/format";

export default function Account() {
  const { colors } = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const toast = useToast();
  const { user, signOut, setUser } = useAuth();
  const pay = useApi<any>("/payments/config");
  const [editing, setEditing] = useState(false);
  const [name, setName] = useState(user?.name ?? "");
  const [busy, setBusy] = useState(false);
  const bottomChrome = usesNativeTabs ? insets.bottom : 0;
  if (!user) return null;

  const save = async () => {
    setBusy(true);
    try {
      setUser(await api("/me", { method: "PUT", body: { name } }));
      setEditing(false);
      toast("تم حفظ الاسم");
    } catch (e: any) {
      toast(e.message, "error");
    } finally {
      setBusy(false);
    }
  };

  const links: { icon: IconName; label: string; to: string; testID: string; show: boolean }[] = [
    { icon: "id-card", label: "الهوية والتخصصات والاشتراك", to: "/tech/profile", testID: "account-tech-profile-link", show: user.role === "technician" },
    { icon: "notifications", label: "الإشعارات", to: "/notifications", testID: "account-notifications-link", show: true },
  ];

  return (
    <View style={{ flex: 1, backgroundColor: colors.surface }}>
      <ScrollView contentContainerStyle={{ paddingTop: insets.top + 16, padding: 16, gap: 16, paddingBottom: bottomChrome + 24 }}>
        <Txt variant="h1">حسابي</Txt>
        <Card style={{ gap: 12 }} testID="account-profile-card">
          <Row gap={12}>
            <View style={{ width: 64, height: 64, borderRadius: 32, backgroundColor: colors.brand, alignItems: "center", justifyContent: "center" }}>
              <Txt variant="h1" color={colors.onBrand} center>
                {user.name[0]}
              </Txt>
            </View>
            <View style={{ flex: 1, gap: 2 }}>
              <Txt variant="h2" testID="account-name">
                {user.name}
              </Txt>
              <Txt color={colors.muted} testID="account-phone">
                {phoneFmt(user.phone)}
              </Txt>
              <Badge label={ROLE_AR[user.role]} tone="brand" testID="account-role-badge" />
            </View>
          </Row>
          {editing ? (
            <View style={{ gap: 8 }}>
              <Field testID="account-name-input" value={name} onChangeText={setName} label="الاسم" />
              <Row gap={8}>
                <Btn testID="account-name-save-button" small label="حفظ" loading={busy} onPress={save} style={{ flex: 1 }} />
                <Btn testID="account-name-cancel-button" small variant="outline" label="إلغاء" onPress={() => setEditing(false)} />
              </Row>
            </View>
          ) : (
            <Btn testID="account-edit-name-button" small variant="soft" icon="create" label="تعديل الاسم" onPress={() => setEditing(true)} />
          )}
        </Card>

        {links
          .filter((l) => l.show)
          .map((l) => (
            <Card key={l.to} testID={l.testID} onPress={() => router.push(l.to as any)}>
              <Row gap={12}>
                <Icon name={l.icon} size={22} color={colors.brand} />
                <Txt variant="title" style={{ flex: 1 }}>
                  {l.label}
                </Txt>
                <Icon name="chevron-back" size={20} color={colors.muted} />
              </Row>
            </Card>
          ))}

        <Card style={{ gap: 8 }} testID="account-payments-card">
          <Row gap={12}>
            <Icon name="wallet" size={22} color={colors.brand} />
            <Txt variant="title" style={{ flex: 1 }}>
              طرق الدفع
            </Txt>
          </Row>
          <Row style={{ justifyContent: "space-between" }}>
            <Txt>كاش بعد الشغل</Txt>
            <Badge label="مفعل" tone="success" />
          </Row>
          <Row style={{ justifyContent: "space-between" }}>
            <Txt>دفع إلكتروني (بوابة مصرية)</Txt>
            <Badge label={pay.data?.online_enabled ? "مفعل" : "قريبًا"} tone={pay.data?.online_enabled ? "success" : "muted"} />
          </Row>
          <Txt variant="caption" color={colors.muted}>
            لا نخزن أي بيانات بطاقات بنكية على خوادمنا.
          </Txt>
        </Card>

        <Card style={{ gap: 4 }}>
          <Txt weight="700">خدمات — المنصورة، الدقهلية</Txt>
          <Txt variant="caption" color={colors.muted}>
            الأسعار بالجنيه المصري (ج.م). خدمة العملاء: من خلال المحادثة داخل كل طلب.
          </Txt>
        </Card>

        <Btn
          testID="account-logout-button"
          variant="danger"
          icon="log-out"
          label="تسجيل الخروج"
          onPress={async () => {
            await signOut();
            router.replace("/login");
          }}
        />
      </ScrollView>
    </View>
  );
}