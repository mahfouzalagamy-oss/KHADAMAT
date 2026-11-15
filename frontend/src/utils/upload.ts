import { Platform } from "react-native";
import { fetch as expoFetch } from "expo/fetch";

export type LocalFile = {
  uri: string;
  name?: string;
  mimeType?: string;
};

export type UploadOptions = {
  files: Record<string, LocalFile>;
  fields?: Record<string, string>;
  method?: "POST" | "PUT";
  headers?: Record<string, string>;
  signal?: AbortSignal;
};

export function fileNameFor(file: LocalFile): string {
  return file.name || file.uri.split("?")[0].split("/").pop() || "file";
}

export async function toFormDataPart(file: LocalFile): Promise<Blob> {
  if (Platform.OS === "web") {
    const blob = await (await fetch(file.uri)).blob();
    const type = file.mimeType || blob.type;
    return type && type !== blob.type ? new Blob([blob], { type }) : blob;
  }
  const blob = await (await expoFetch(file.uri)).blob();
  return file.mimeType && file.mimeType !== blob.type ? new Blob([blob], { type: file.mimeType }) : blob;
}

export async function uploadForm(url: string, opts: UploadOptions): Promise<Response> {
  const form = new FormData();
  for (const [k, v] of Object.entries(opts.fields ?? {})) form.append(k, v);
  for (const [field, file] of Object.entries(opts.files)) {
    form.append(field, await toFormDataPart(file), fileNameFor(file));
  }
  const init = {
    method: opts.method ?? "POST",
    body: form,
    headers: opts.headers,
    signal: opts.signal,
  };
  return Platform.OS === "web" ? fetch(url, init) : expoFetch(url, init);
}