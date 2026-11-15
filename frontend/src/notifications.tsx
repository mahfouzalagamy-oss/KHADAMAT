import { useEffect, useRef } from "react";
import { Platform } from "react-native";
import { useRouter } from "expo-router";
import * as Device from "expo-device";
import * as Notifications from "expo-notifications";
import Constants from "expo-constants";
import { api } from "@/src/api";
import { useAuth } from "@/src/auth";
import { queryClient } from "@/src/query-client";
import { useToast } from "@/src/ui";

if (Platform.OS !== "web") {
  Notifications.setNotificationHandler({
    handleNotification: async () => ({
      shouldShowAlert: true,
      shouldShowBanner: true,
      shouldShowList: true,
      shouldPlaySound: true,
      shouldSetBadge: true,
    }),
  });
}

async function obtainPushToken(): Promise<string | null> {
  if (Platform.OS === "web" || !Device.isDevice) return null;

  if (Platform.OS === "android") {
    await Notifications.setNotificationChannelAsync("khadamat_alerts", {
      name: "إشعارات خدمات",
      importance: Notifications.AndroidImportance.MAX,
      vibrationPattern: [0, 250, 250, 250],
      lightColor: "#059669",
    });
  }

  const { status: existingStatus } = await Notifications.getPermissionsAsync();
  let finalStatus = existingStatus;
  if (existingStatus !== "granted") {
    const { status } = await Notifications.requestPermissionsAsync();
    finalStatus = status;
  }
  if (finalStatus !== "granted") return null;

  try {
    const devicePush = await Notifications.getDevicePushTokenAsync();
    if (devicePush?.data) return String(devicePush.data);
  } catch {}

  try {
    const projectId =
      Constants?.expoConfig?.extra?.eas?.projectId ?? Constants?.easConfig?.projectId;
    const expoPush = await Notifications.getExpoPushTokenAsync(
      projectId ? { projectId } : undefined,
    );
    return expoPush?.data ?? null;
  } catch {
    return null;
  }
}

export function PushNotificationsManager() {
  const { user } = useAuth();
  const router = useRouter();
  const toast = useToast();
  const registeredForUser = useRef<string | null>(null);

  useEffect(() => {
    if (Platform.OS === "web") return;

    const navigateFromData = (data: Record<string, any> | undefined) => {
      const rid = data?.request_id;
      if (typeof rid === "string" && rid.length > 0) {
        router.push(`/request/${rid}`);
      }
    };

    Notifications.getLastNotificationResponseAsync()
      .then((res) => {
        if (res?.notification?.request?.content?.data) {
          navigateFromData(res.notification.request.content.data as Record<string, any>);
        }
      })
      .catch(() => {});

    const receivedSub = Notifications.addNotificationReceivedListener((notification) => {
      const title = notification.request.content.title;
      queryClient.invalidateQueries({ queryKey: ["/notifications"] });
      queryClient.invalidateQueries({ queryKey: ["/requests"] });
      if (title) toast(title, "info");
    });

    const responseSub = Notifications.addNotificationResponseReceivedListener((response) => {
      const data = response.notification.request.content.data as Record<string, any> | undefined;
      navigateFromData(data);
    });

    return () => {
      receivedSub.remove();
      responseSub.remove();
    };
  }, [router, toast]);

  useEffect(() => {
    if (!user) {
      registeredForUser.current = null;
      return;
    }
    if (Platform.OS === "web" || registeredForUser.current === user.id) return;

    let cancelled = false;
    (async () => {
      const token = await obtainPushToken();
      if (!token || cancelled) return;
      try {
        await api("/devices/push-token", {
          method: "POST",
          body: {
            token,
            platform: Platform.OS === "ios" ? "ios" : "android",
          },
        });
        registeredForUser.current = user.id;
      } catch {}
    })();

    return () => {
      cancelled = true;
    };
  }, [user]);

  return null;
}