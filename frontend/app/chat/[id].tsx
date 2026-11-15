import { useCallback, useEffect, useRef, useState } from "react";
import { FlatList, Pressable, TextInput, View } from "react-native";
import { useLocalSearchParams } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { KeyboardAvoidingView } from "react-native-keyboard-controller";
import { api, useApi } from "@/src/api";
import { useAuth } from "@/src/auth";
import { storage } from "@/src/utils/storage";
import { useOnline } from "@/src/net";
import { Empty, FONT, haptic, Header, Icon, Loading, OfflineBanner, Txt } from "@/src/ui";
import { useTheme } from "@/src/theme";
import { STATUS, timeFmt } from "@/src/format";

type Msg = { id: string; client_id?: string; sender_id: string; text: string; created_at: string; pending?: boolean };

export default function ChatScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { colors } = useTheme();
  const insets = useSafeAreaInsets();
  const { user } = useAuth();
  const online = useOnline();
  const req = useApi<any>(`/requests/${id}`);
  const msgs = useApi<Msg[]>(`/requests/${id}/messages`, 4000);
  const [text, setText] = useState("");
  const [outbox, setOutbox] = useState<Msg[]>([]);
  const listRef = useRef<FlatList>(null);
  const draftKey = `chat_draft_${id}`;
  const outKey = `chat_outbox_${id}`;
  const flushing = useRef(false);

  useEffect(() => {
    (async () => {
      const d = await storage.getItem(draftKey, "");
      if (typeof d === "string") setText(d);
      const o = await storage.getItem(outKey, "[]");
      try {
        setOutbox(JSON.parse(String(o)));
      } catch {}
    })();
  }, [draftKey, outKey]);

  const saveOutbox = useCallback(
    (o: Msg[]) => {
      setOutbox(o);
      storage.setItem(outKey, JSON.stringify(o));
    },
    [outKey],
  );

  const flush = useCallback(async () => {
    if (flushing.current || !outbox.length) return;
    flushing.current = true;
    let rest = [...outbox];
    for (const m of outbox) {
      try {
        await api(`/requests/${id}/messages`, { body: { text: m.text, client_id: m.client_id } });
        rest = rest.filter((x) => x.client_id !== m.client_id);
      } catch {
        break;
      }
    }
    saveOutbox(rest);
    flushing.current = false;
    msgs.refetch();
  }, [outbox, id, saveOutbox, msgs]);

  useEffect(() => {
    if (online && outbox.length) flush();
  }, [online, outbox.length, flush]);

  const send = async () => {
    const t = text.trim();
    if (!t) return;
    haptic();
    const m: Msg = {
      id: `local-${Date.now()}`,
      client_id: `${user?.id}-${Date.now()}`,
      sender_id: user!.id,
      text: t,
      created_at: new Date().toISOString(),
      pending: true,
    };
    setText("");
    storage.setItem(draftKey, "");
    if (!online) return saveOutbox([...outbox, m]);
    try {
      await api(`/requests/${id}/messages`, { body: { text: t, client_id: m.client_id } });
      msgs.refetch();
    } catch {
      saveOutbox([...outbox, m]);
    }
  };

  const serverIds = new Set((msgs.data ?? []).map((m) => m.client_id).filter(Boolean));
  const all = [...(msgs.data ?? []), ...outbox.filter((m) => !serverIds.has(m.client_id))];
  const r = req.data;
  const other = r ? (user?.id === r.customer_id ? r.technician_name : r.customer_name) : "";

  return (
    <View style={{ flex: 1, backgroundColor: colors.surface }}>
      <Header title={other || "المحادثة"} subtitle={r ? `${r.category_name} • ${STATUS[r.status]?.label ?? ""}` : undefined} />
      {!online ? <OfflineBanner text="غير متصل — رسائلك هتتبعت تلقائي أول ما يرجع النت" /> : null}
      <KeyboardAvoidingView behavior="padding" style={{ flex: 1 }}>
        {msgs.isLoading ? (
          <Loading />
        ) : msgs.isError ? (
          <Empty testID="chat-unavailable" icon="chatbubbles" title="المحادثة غير متاحة" body={(msgs.error as Error).message} />
        ) : (
          <FlatList
            ref={listRef}
            testID="chat-messages-list"
            data={all}
            keyExtractor={(m) => m.client_id || m.id}
            contentContainerStyle={{ padding: 16, gap: 8, flexGrow: 1 }}
            onContentSizeChange={() => listRef.current?.scrollToEnd({ animated: true })}
            ListEmptyComponent={<Empty icon="chatbubble-ellipses" title="قول أهلاً!" body="اتفق على التفاصيل والموعد هنا" />}
            renderItem={({ item }) => {
              const mine = item.sender_id === user?.id;
              return (
                <View
                  testID={mine ? "chat-message-mine" : "chat-message-other"}
                  style={{
                    alignSelf: mine ? "flex-start" : "flex-end",
                    maxWidth: "80%",
                    backgroundColor: mine ? colors.brand : colors.surfaceSecondary,
                    borderWidth: mine ? 0 : 1,
                    borderColor: colors.border,
                    borderRadius: 20,
                    borderBottomLeftRadius: mine ? 6 : 20,
                    borderBottomRightRadius: mine ? 20 : 6,
                    paddingHorizontal: 14,
                    paddingVertical: 8,
                  }}
                >
                  <Txt color={mine ? colors.onBrand : colors.onSurface}>{item.text}</Txt>
                  <View style={{ flexDirection: "row-reverse", alignItems: "center", gap: 4 }}>
                    <Txt variant="caption" color={mine ? colors.brandTertiary : colors.muted}>
                      {timeFmt(new Date(item.created_at))}
                    </Txt>
                    {item.pending ? <Icon name="time-outline" size={12} color={colors.brandTertiary} /> : null}
                  </View>
                </View>
              );
            }}
          />
        )}
        <View
          style={{
            flexDirection: "row-reverse",
            alignItems: "flex-end",
            gap: 8,
            paddingHorizontal: 12,
            paddingTop: 8,
            paddingBottom: insets.bottom + 8,
            backgroundColor: colors.surfaceSecondary,
            borderTopWidth: 1,
            borderTopColor: colors.border,
          }}
        >
          <TextInput
            testID="chat-input"
            value={text}
            onChangeText={(t) => {
              setText(t);
              storage.setItem(draftKey, t);
            }}
            placeholder="اكتب رسالتك..."
            placeholderTextColor={colors.muted}
            multiline
            style={{
              flex: 1,
              minHeight: 44,
              maxHeight: 120,
              borderRadius: 22,
              backgroundColor: colors.surfaceTertiary,
              paddingHorizontal: 16,
              paddingVertical: 10,
              fontFamily: FONT,
              fontSize: 15,
              color: colors.onSurface,
              textAlign: "right",
              writingDirection: "rtl",
            }}
          />
          <Pressable
            testID="chat-send-button"
            onPress={send}
            disabled={!text.trim() || msgs.isError}
            style={({ pressed }) => ({
              width: 44,
              height: 44,
              borderRadius: 22,
              backgroundColor: text.trim() ? colors.brand : colors.border,
              alignItems: "center",
              justifyContent: "center",
              transform: [{ scale: pressed ? 0.9 : 1 }],
            })}
          >
            <Icon name="send" size={20} color={colors.onBrand} style={{ transform: [{ scaleX: -1 }] }} />
          </Pressable>
        </View>
      </KeyboardAvoidingView>
    </View>
  );
}