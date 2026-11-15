import React, { createContext, useCallback, useContext, useRef, useState } from "react";
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleProp,
  Text,
  TextInput,
  TextInputProps,
  TextProps,
  View,
  ViewStyle,
} from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { useRouter } from "expo-router";
import * as Haptics from "expo-haptics";
import Ionicons from "@react-native-vector-icons/ionicons";
import Animated, { FadeInDown, FadeOutDown } from "react-native-reanimated";
import { useTheme, ThemeColors } from "@/src/theme";
import { Tone } from "@/src/format";

export const Icon = Ionicons;
export type IconName = React.ComponentProps<typeof Ionicons>["name"];
export const FONT = "Cairo";

export const haptic = () => Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => {});

const SIZES = { display: 30, h1: 24, h2: 20, title: 16, body: 14, caption: 12 };
type Variant = keyof typeof SIZES;

export function Txt({
  variant = "body",
  color,
  weight,
  center,
  style,
  ...rest
}: TextProps & { variant?: Variant; color?: string; weight?: "400" | "500" | "700"; center?: boolean }) {
  const { colors } = useTheme();
  const size = SIZES[variant];
  const heavy = variant === "display" || variant === "h1" || variant === "h2" || variant === "title";
  return (
    <Text
      {...rest}
      style={[
        {
          fontFamily: FONT,
          fontSize: size,
          lineHeight: Math.round(size * 1.55),
          color: color ?? colors.onSurface,
          textAlign: center ? "center" : "right",
          writingDirection: "rtl",
          fontWeight: weight ?? (heavy ? "700" : "400"),
        },
        style,
      ]}
    />
  );
}

export function toneColors(c: ThemeColors, tone: Tone) {
  switch (tone) {
    case "success":
      return { bg: c.brandTertiary, fg: c.onBrandTertiary, solid: c.success };
    case "warning":
      return { bg: c.warningSoft, fg: c.onWarningSoft, solid: c.warning };
    case "error":
      return { bg: c.errorSoft, fg: c.onErrorSoft, solid: c.error };
    case "info":
      return { bg: c.infoSoft, fg: c.onInfoSoft, solid: c.info };
    case "muted":
      return { bg: c.divider, fg: c.muted, solid: c.muted };
    default:
      return { bg: c.surfaceTertiary, fg: c.onSurfaceTertiary, solid: c.brand };
  }
}

type BtnVariant = "primary" | "secondary" | "soft" | "danger" | "outline";

export function Btn({
  label,
  onPress,
  variant = "primary",
  icon,
  loading,
  disabled,
  testID,
  style,
  small,
}: {
  label: string;
  onPress?: () => void;
  variant?: BtnVariant;
  icon?: IconName;
  loading?: boolean;
  disabled?: boolean;
  testID?: string;
  style?: StyleProp<ViewStyle>;
  small?: boolean;
}) {
  const { colors } = useTheme();
  const bg = {
    primary: colors.brand,
    secondary: colors.brandSecondary,
    soft: colors.brandTertiary,
    danger: colors.errorSoft,
    outline: colors.surfaceSecondary,
  }[variant];
  const fg = {
    primary: colors.onBrand,
    secondary: colors.onBrandSecondary,
    soft: colors.onBrandTertiary,
    danger: colors.onErrorSoft,
    outline: colors.onSurface,
  }[variant];
  return (
    <Pressable
      testID={testID}
      accessibilityRole="button"
      disabled={disabled || loading}
      onPress={() => {
        haptic();
        onPress?.();
      }}
      style={({ pressed }) => [
        {
          minHeight: small ? 40 : 52,
          borderRadius: 999,
          paddingHorizontal: small ? 16 : 24,
          backgroundColor: bg,
          flexDirection: "row-reverse",
          alignItems: "center",
          justifyContent: "center",
          gap: 8,
          opacity: disabled ? 0.45 : 1,
          transform: [{ scale: pressed ? 0.97 : 1 }],
          borderWidth: variant === "outline" ? 1 : 0,
          borderColor: colors.borderStrong,
        },
        style,
      ]}
    >
      {loading ? (
        <ActivityIndicator color={fg} />
      ) : (
        <>
          {icon ? <Icon name={icon} size={small ? 16 : 20} color={fg} /> : null}
          <Txt variant={small ? "body" : "title"} color={fg} weight="700">
            {label}
          </Txt>
        </>
      )}
    </Pressable>
  );
}

export function IconBtn({
  icon,
  onPress,
  testID,
  badge,
  tint,
}: {
  icon: IconName;
  onPress: () => void;
  testID: string;
  badge?: number;
  tint?: string;
}) {
  const { colors } = useTheme();
  return (
    <Pressable
      testID={testID}
      onPress={onPress}
      hitSlop={6}
      style={({ pressed }) => ({
        width: 44,
        height: 44,
        borderRadius: 22,
        backgroundColor: colors.surfaceTertiary,
        alignItems: "center",
        justifyContent: "center",
        transform: [{ scale: pressed ? 0.92 : 1 }],
      })}
    >
      <Icon name={icon} size={22} color={tint ?? colors.onSurfaceTertiary} />
      {badge ? (
        <View
          style={{
            position: "absolute",
            top: 4,
            right: 4,
            minWidth: 18,
            height: 18,
            borderRadius: 9,
            backgroundColor: colors.error,
            alignItems: "center",
            justifyContent: "center",
            paddingHorizontal: 4,
          }}
        >
          <Text style={{ color: colors.onError, fontSize: 10, fontFamily: FONT }}>{badge > 9 ? "9+" : badge}</Text>
        </View>
      ) : null}
    </Pressable>
  );
}

export function Card({
  children,
  style,
  testID,
  onPress,
}: {
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
  testID?: string;
  onPress?: () => void;
}) {
  const { colors } = useTheme();
  const base: ViewStyle = {
    backgroundColor: colors.surfaceSecondary,
    borderRadius: 20,
    padding: 16,
    borderWidth: 1,
    borderColor: colors.border,
    shadowColor: colors.shadow,
    shadowOpacity: 0.06,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 4 },
    elevation: 2,
  };
  if (!onPress)
    return (
      <View testID={testID} style={[base, style]}>
        {children}
      </View>
    );
  return (
    <Pressable
      testID={testID}
      onPress={() => {
        haptic();
        onPress();
      }}
      style={({ pressed }) => [base, { transform: [{ scale: pressed ? 0.98 : 1 }] }, style]}
    >
      {children}
    </Pressable>
  );
}

export function Row({ children, style, gap = 8 }: { children: React.ReactNode; style?: StyleProp<ViewStyle>; gap?: number }) {
  return <View style={[{ flexDirection: "row-reverse", alignItems: "center", gap }, style]}>{children}</View>;
}

export function Badge({ label, tone = "brand", icon, testID }: { label: string; tone?: Tone; icon?: IconName; testID?: string }) {
  const { colors } = useTheme();
  const t = toneColors(colors, tone);
  return (
    <View
      testID={testID}
      style={{
        flexDirection: "row-reverse",
        alignItems: "center",
        gap: 4,
        backgroundColor: t.bg,
        paddingHorizontal: 10,
        paddingVertical: 2,
        borderRadius: 999,
        alignSelf: "flex-end",
      }}
    >
      {icon ? <Icon name={icon} size={12} color={t.fg} /> : null}
      <Txt variant="caption" color={t.fg} weight="700">
        {label}
      </Txt>
    </View>
  );
}

export function Chip({
  label,
  selected,
  onPress,
  testID,
  icon,
}: {
  label: string;
  selected?: boolean;
  onPress: () => void;
  testID: string;
  icon?: IconName;
}) {
  const { colors } = useTheme();
  return (
    <Pressable
      testID={testID}
      onPress={() => {
        Haptics.selectionAsync().catch(() => {});
        onPress();
      }}
      style={{
        height: 36,
        flexShrink: 0,
        paddingHorizontal: 16,
        borderRadius: 999,
        flexDirection: "row-reverse",
        alignItems: "center",
        gap: 6,
        backgroundColor: selected ? colors.brand : colors.surfaceSecondary,
        borderWidth: 1,
        borderColor: selected ? colors.brand : colors.border,
      }}
    >
      {icon ? <Icon name={icon} size={14} color={selected ? colors.onBrand : colors.onSurfaceSecondary} /> : null}
      <Txt variant="body" weight="500" color={selected ? colors.onBrand : colors.onSurfaceSecondary}>
        {label}
      </Txt>
    </Pressable>
  );
}

export function ChipRow({ children, testID }: { children: React.ReactNode; testID?: string }) {
  return (
    <ScrollView
      testID={testID}
      horizontal
      showsHorizontalScrollIndicator={false}
      style={{ flexGrow: 0, height: 56, transform: [{ scaleX: -1 }] }}
      contentContainerStyle={{ gap: 8, paddingHorizontal: 16, alignItems: "center" }}
    >
      {React.Children.map(children, (c) =>
        c ? <View style={{ transform: [{ scaleX: -1 }], flexShrink: 0 }}>{c}</View> : null,
      )}
    </ScrollView>
  );
}

export function Field({
  label,
  testID,
  style,
  multiline,
  ...rest
}: TextInputProps & { label?: string; testID: string }) {
  const { colors } = useTheme();
  const [focus, setFocus] = useState(false);
  return (
    <View style={{ gap: 6 }}>
      {label ? (
        <Txt variant="body" weight="500" color={colors.onSurfaceSecondary}>
          {label}
        </Txt>
      ) : null}
      <TextInput
        testID={testID}
        placeholderTextColor={colors.muted}
        multiline={multiline}
        onFocus={() => setFocus(true)}
        onBlur={() => setFocus(false)}
        {...rest}
        style={[
          {
            fontFamily: FONT,
            fontSize: 16,
            color: colors.onSurface,
            backgroundColor: colors.surfaceSecondary,
            borderWidth: focus ? 1.5 : 1,
            borderColor: focus ? colors.brand : colors.border,
            borderRadius: 12,
            paddingHorizontal: 16,
            paddingVertical: 12,
            minHeight: multiline ? 120 : 52,
            textAlign: "right",
            textAlignVertical: multiline ? "top" : "center",
            writingDirection: "rtl",
          },
          style,
        ]}
      />
    </View>
  );
}

export function Header({
  title,
  subtitle,
  back = true,
  right,
}: {
  title: string;
  subtitle?: string;
  back?: boolean;
  right?: React.ReactNode;
}) {
  const { colors } = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  return (
    <View
      style={{
        paddingTop: insets.top + 8,
        paddingBottom: 12,
        paddingHorizontal: 16,
        backgroundColor: colors.surfaceSecondary,
        borderBottomWidth: 1,
        borderBottomColor: colors.border,
        flexDirection: "row-reverse",
        alignItems: "center",
        gap: 12,
      }}
    >
      {back ? (
        <IconBtn
          testID="header-back-button"
          icon="arrow-forward"
          onPress={() => (router.canGoBack() ? router.back() : router.replace("/"))}
        />
      ) : null}
      <View style={{ flex: 1 }}>
        <Txt variant="h2" numberOfLines={1}>
          {title}
        </Txt>
        {subtitle ? (
          <Txt variant="caption" color={colors.muted} numberOfLines={1}>
            {subtitle}
          </Txt>
        ) : null}
      </View>
      {right}
    </View>
  );
}

export function SectionTitle({ title, action }: { title: string; action?: React.ReactNode }) {
  return (
    <Row style={{ justifyContent: "space-between", marginBottom: 8 }}>
      <Txt variant="title">{title}</Txt>
      {action}
    </Row>
  );
}

export function Loading() {
  const { colors } = useTheme();
  return (
    <View style={{ flex: 1, alignItems: "center", justifyContent: "center", padding: 32 }}>
      <ActivityIndicator size="large" color={colors.brand} />
    </View>
  );
}

export function Empty({
  icon,
  title,
  body,
  action,
  testID,
}: {
  icon: IconName;
  title: string;
  body?: string;
  action?: React.ReactNode;
  testID?: string;
}) {
  const { colors } = useTheme();
  return (
    <View testID={testID} style={{ alignItems: "center", padding: 32, gap: 8 }}>
      <View
        style={{
          width: 88,
          height: 88,
          borderRadius: 44,
          backgroundColor: colors.brandTertiary,
          alignItems: "center",
          justifyContent: "center",
          marginBottom: 8,
        }}
      >
        <Icon name={icon} size={40} color={colors.brand} />
      </View>
      <Txt variant="title" center>
        {title}
      </Txt>
      {body ? (
        <Txt center color={colors.muted}>
          {body}
        </Txt>
      ) : null}
      {action ? <View style={{ marginTop: 8 }}>{action}</View> : null}
    </View>
  );
}

export function ErrorView({ message, onRetry }: { message?: string; onRetry: () => void }) {
  return (
    <Empty
      testID="error-view"
      icon="cloud-offline"
      title="حصلت مشكلة في الاتصال"
      body={message}
      action={<Btn testID="error-retry-button" label="حاول مرة أخرى" icon="refresh" onPress={onRetry} small />}
    />
  );
}

export function Stars({
  value,
  size = 16,
  onChange,
  testIDPrefix,
}: {
  value: number;
  size?: number;
  onChange?: (v: number) => void;
  testIDPrefix?: string;
}) {
  const { colors } = useTheme();
  return (
    <Row gap={onChange ? 8 : 2}>
      {[1, 2, 3, 4, 5].map((i) => (
        <Pressable
          key={i}
          testID={testIDPrefix ? `${testIDPrefix}-${i}` : undefined}
          disabled={!onChange}
          onPress={() => onChange?.(i)}
          hitSlop={4}
        >
          <Icon name={i <= Math.round(value) ? "star" : "star-outline"} size={size} color={colors.star} />
        </Pressable>
      ))}
    </Row>
  );
}

export function OfflineBanner({ text }: { text: string }) {
  const { colors } = useTheme();
  return (
    <View
      testID="offline-banner"
      style={{
        flexDirection: "row-reverse",
        alignItems: "center",
        gap: 8,
        backgroundColor: colors.warningSoft,
        paddingHorizontal: 16,
        paddingVertical: 8,
      }}
    >
      <Icon name="cloud-offline" size={16} color={colors.onWarningSoft} />
      <Txt variant="caption" color={colors.onWarningSoft} weight="700" style={{ flex: 1 }}>
        {text}
      </Txt>
    </View>
  );
}

type ToastKind = "success" | "error" | "info";
const ToastCtx = createContext<(msg: string, kind?: ToastKind) => void>(() => {});

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const { colors } = useTheme();
  const insets = useSafeAreaInsets();
  const [toast, setToast] = useState<{ msg: string; kind: ToastKind; key: number } | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const show = useCallback((msg: string, kind: ToastKind = "success") => {
    if (timer.current) clearTimeout(timer.current);
    setToast({ msg, kind, key: Date.now() });
    timer.current = setTimeout(() => setToast(null), 3000);
  }, []);
  const bg = toast?.kind === "error" ? colors.error : toast?.kind === "info" ? colors.surfaceInverse : colors.brandDeep;
  return (
    <ToastCtx.Provider value={show}>
      {children}
      {toast ? (
        <Animated.View
          key={toast.key}
          entering={FadeInDown}
          exiting={FadeOutDown}
          pointerEvents="none"
          testID="toast-message"
          style={{
            position: "absolute",
            bottom: insets.bottom + 96,
            left: 16,
            right: 16,
            backgroundColor: bg,
            borderRadius: 16,
            paddingHorizontal: 16,
            paddingVertical: 12,
            flexDirection: "row-reverse",
            alignItems: "center",
            gap: 8,
            elevation: 6,
          }}
        >
          <Icon
            name={toast.kind === "error" ? "alert-circle" : toast.kind === "info" ? "information-circle" : "checkmark-circle"}
            size={20}
            color={colors.onBrand}
          />
          <Txt color={colors.onBrand} weight="500" style={{ flex: 1 }}>
            {toast.msg}
          </Txt>
        </Animated.View>
      ) : null}
    </ToastCtx.Provider>
  );
}

export const useToast = () => useContext(ToastCtx);