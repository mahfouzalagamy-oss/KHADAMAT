import { useNetInfo } from "@react-native-community/netinfo";

export function useOnline() {
  const s = useNetInfo();
  return s.isConnected !== false;
}