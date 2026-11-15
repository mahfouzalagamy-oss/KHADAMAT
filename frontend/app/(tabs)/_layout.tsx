import { Redirect, Tabs } from "expo-router";
import { NativeTabs } from "expo-router/unstable-native-tabs";
import { Platform } from "react-native";
import { useAuth } from "@/src/auth";
import { usesNativeTabs } from "@/src/navigation";
import { useTheme } from "@/src/theme";
import { FONT, Icon, IconName } from "@/src/ui";

export const unstable_settings = { initialRouteName: "index" };

const TABS: { name: string; label: string; icon: IconName; sf: string }[] = [
  { name: "index", label: "الرئيسية", icon: "home", sf: "house.fill" },
  { name: "bookings", label: "الطلبات", icon: "calendar", sf: "calendar" },
  { name: "chat", label: "المحادثات", icon: "chatbubbles", sf: "bubble.left.and.bubble.right.fill" },
  { name: "account", label: "حسابي", icon: "person", sf: "person.crop.circle.fill" },
];

export default function TabsLayout() {
  const { user, loading } = useAuth();
  const { colors } = useTheme();
  if (!loading && !user) return <Redirect href="/login" />;

  if (usesNativeTabs) {
    return (
      <NativeTabs tintColor={colors.brand}>
        {TABS.map((t) => (
          <NativeTabs.Trigger key={t.name} name={t.name}>
            <NativeTabs.Trigger.Icon sf={t.sf as any} />
            <NativeTabs.Trigger.Label>{t.label}</NativeTabs.Trigger.Label>
          </NativeTabs.Trigger>
        ))}
      </NativeTabs>
    );
  }

  return (
    <Tabs
      initialRouteName="index"
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: colors.brand,
        tabBarInactiveTintColor: colors.muted,
        tabBarLabelStyle: { fontFamily: FONT, fontSize: 12, fontWeight: "700" },
        tabBarStyle: {
          backgroundColor: colors.surfaceSecondary,
          borderTopColor: colors.border,
          ...(Platform.OS === "web" ? { height: 64 } : {}),
        },
        tabBarItemStyle: { alignSelf: "center" },
      }}
    >
      {[...TABS].reverse().map((t) => (
        <Tabs.Screen
          key={t.name}
          name={t.name}
          options={{
            title: t.label,
            ...(t.name === "chat" && (user?.role === "admin" || user?.role === "company") ? { href: null } : {}),
            tabBarButtonTestID: `tab-${t.name}`,
            tabBarIcon: ({ color, focused }) => (
              <Icon name={(focused ? t.icon : `${t.icon}-outline`) as IconName} size={24} color={color} />
            ),
          }}
        />
      ))}
    </Tabs>
  );
}