import { useCallback } from "react";
import { useFocusEffect } from "expo-router";
import { useQuery } from "@tanstack/react-query";
import { storage } from "@/src/utils/storage";

const BASE = `${process.env.EXPO_PUBLIC_BACKEND_URL || "http://localhost:8000"}/api`;
export const TOKEN_KEY = "auth_token";

let tokenCache: string | null = null;
export function setTokenCache(t: string | null) {
  tokenCache = t;
}

export class ApiError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

export async function api<T = any>(path: string, opts: { method?: string; body?: unknown } = {}): Promise<T> {
  const token = tokenCache ?? (await storage.secureGet(TOKEN_KEY, null));
  let res: Response;
  try {
    res = await fetch(BASE + path, {
      method: opts.method ?? (opts.body ? "POST" : "GET"),
      headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      body: opts.body ? JSON.stringify(opts.body) : undefined,
    });
  } catch {
    throw new ApiError("لا يوجد اتصال بالإنترنت", 0);
  }
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const msg = typeof data.detail === "string" ? data.detail : "تأكد من البيانات المدخلة وحاول مرة أخرى";
    throw new ApiError(msg, res.status);
  }
  return data as T;
}

export function useApi<T = any>(path: string | null, poll?: number) {
  const q = useQuery<T>({
    queryKey: [path],
    queryFn: () => api<T>(path as string),
    enabled: !!path,
    refetchInterval: poll,
  });
  const { refetch } = q;
  useFocusEffect(
    useCallback(() => {
      if (path) refetch();
    }, [path, refetch]),
  );
  return q;
}