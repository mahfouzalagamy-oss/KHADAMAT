import { useMemo } from "react";
import { Appearance, StyleSheet, useColorScheme } from "react-native";

export type ColorScheme = "light" | "dark";

const light = {
  surface: "#F8FAFC",
  onSurface: "#0F172A",
  surfaceSecondary: "#FFFFFF",
  onSurfaceSecondary: "#0F172A",
  surfaceTertiary: "#ECFDF5",
  onSurfaceTertiary: "#064E3B",
  surfaceInverse: "#0F172A",
  onSurfaceInverse: "#F8FAFC",
  muted: "#64748B",

  brand: "#059669",
  onBrand: "#FFFFFF",
  brandPrimary: "#10B981",
  onBrandPrimary: "#FFFFFF",
  brandSecondary: "#84CC16",
  onBrandSecondary: "#064E3B",
  brandTertiary: "#D1FAE5",
  onBrandTertiary: "#065F46",
  brandDeep: "#064E3B",
  onBrandDeep: "#ECFDF5",

  success: "#22C55E",
  onSuccess: "#FFFFFF",
  warning: "#F59E0B",
  onWarning: "#FFFFFF",
  warningSoft: "#FEF3C7",
  onWarningSoft: "#92400E",
  error: "#EF4444",
  onError: "#FFFFFF",
  errorSoft: "#FEE2E2",
  onErrorSoft: "#991B1B",
  info: "#3B82F6",
  onInfo: "#FFFFFF",
  infoSoft: "#DBEAFE",
  onInfoSoft: "#1E40AF",
  star: "#F59E0B",

  border: "#E2E8F0",
  borderStrong: "#CBD5E1",
  divider: "#F1F5F9",
  shadow: "#064E3B",
};

export type ThemeColors = typeof light;

export const defaultScheme = "light" satisfies ColorScheme;

export const themes: { light: ThemeColors; dark?: ThemeColors } = { light };

export function setColorScheme(scheme: ColorScheme | null) {
  Appearance.setColorScheme?.(scheme ?? "unspecified");
}

setColorScheme?.(themes.dark ? null : defaultScheme);

export const colors = light;

export function useTheme(): { scheme: ColorScheme; colors: ThemeColors } {
  const system = useColorScheme();
  const scheme: ColorScheme = (system === "light" || system === "dark") && themes[system] ? system : defaultScheme;
  return { scheme, colors: themes[scheme] ?? themes.light };
}

export function makeStyles<T extends StyleSheet.NamedStyles<T> | StyleSheet.NamedStyles<any>>(
  factory: (colors: ThemeColors) => T & StyleSheet.NamedStyles<any>,
): () => T {
  return function useStyles(): T {
    const { colors } = useTheme();
    return useMemo(() => StyleSheet.create(factory(colors)), [colors]);
  };
}