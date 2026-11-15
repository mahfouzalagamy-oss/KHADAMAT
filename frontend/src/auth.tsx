import React, { createContext, useCallback, useContext, useEffect, useState } from "react";
import { storage } from "@/src/utils/storage";
import { api, setTokenCache, TOKEN_KEY } from "@/src/api";
import { queryClient } from "@/src/query-client";

export type Role = "customer" | "technician" | "company" | "admin";
export type User = { id: string; phone: string; name: string; role: Role };

type AuthCtx = {
  user: User | null;
  loading: boolean;
  signIn: (token: string, user: User) => Promise<void>;
  signOut: () => Promise<void>;
  setUser: (u: User) => void;
};

const Ctx = createContext<AuthCtx | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      const token = await storage.secureGet(TOKEN_KEY, null);
      if (token) {
        setTokenCache(String(token));
        try {
          setUser(await api<User>("/me"));
        } catch {
          await storage.secureRemove(TOKEN_KEY);
          setTokenCache(null);
        }
      }
      setLoading(false);
    })();
  }, []);

  const signIn = useCallback(async (token: string, u: User) => {
    await storage.secureSet(TOKEN_KEY, token);
    setTokenCache(token);
    queryClient.clear();
    setUser(u);
  }, []);

  const signOut = useCallback(async () => {
    await storage.secureRemove(TOKEN_KEY);
    setTokenCache(null);
    queryClient.clear();
    setUser(null);
  }, []);

  return <Ctx.Provider value={{ user, loading, signIn, signOut, setUser }}>{children}</Ctx.Provider>;
}

export function useAuth() {
  const c = useContext(Ctx);
  if (!c) throw new Error("useAuth outside AuthProvider");
  return c;
}