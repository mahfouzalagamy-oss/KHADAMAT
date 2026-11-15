import { Platform } from "react-native";
import { storage } from "@/src/utils/storage";
import { TOKEN_KEY } from "@/src/api";
import { uploadForm } from "@/src/utils/upload";

const BACKEND_ROOT = process.env.EXPO_PUBLIC_BACKEND_URL || "http://localhost:8000";
const UPLOAD_ENDPOINT = `${BACKEND_ROOT}/api/uploads`;

export function resolveMediaUrl(path?: string | null): string {
  if (!path) return "";
  if (path.startsWith("http://") || path.startsWith("https://")) return path;
  return `${BACKEND_ROOT}${path.startsWith("/") ? "" : "/"}${path}`;
}

export async function pickAndUploadImage(): Promise<string | null> {
  const token = await storage.secureGet(TOKEN_KEY, null);
  const authHeaders: Record<string, string> = token ? { Authorization: `Bearer ${token}` } : {};

  if (Platform.OS === "web") {
    return new Promise((resolve, reject) => {
      const input = document.createElement("input");
      input.type = "file";
      input.accept = "image/jpeg,image/png,image/webp";
      input.onchange = async () => {
        const file = input.files?.[0];
        if (!file) return resolve(null);
        try {
          const form = new FormData();
          form.append("file", file, file.name || "photo.jpg");
          const res = await fetch(UPLOAD_ENDPOINT, {
            method: "POST",
            headers: authHeaders,
            body: form,
          });
          const data = await res.json().catch(() => ({}));
          if (!res.ok) return reject(new Error(data.detail || "فشل رفع الصورة"));
          resolve(data.url as string);
        } catch (err) {
          reject(err);
        }
      };
      input.click();
    });
  }

  const ImagePicker = await import("expo-image-picker");
  const perm = await ImagePicker.requestMediaLibraryPermissionsAsync();
  if (perm.status !== "granted") {
    throw new Error("يرجى السماح بالوصول إلى الصور لاختيار ملف");
  }
  const result = await ImagePicker.launchImageLibraryAsync({
    mediaTypes: ImagePicker.MediaTypeOptions.Images,
    quality: 0.8,
  });
  if (result.canceled || !result.assets?.length) return null;
  const asset = result.assets[0];
  const res = await uploadForm(UPLOAD_ENDPOINT, {
    files: {
      file: {
        uri: asset.uri,
        name: asset.fileName || "photo.jpg",
        mimeType: asset.mimeType || "image/jpeg",
      },
    },
    headers: authHeaders,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.detail || "فشل رفع الصورة");
  return data.url as string;
}