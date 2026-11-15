import struct
import subprocess
import urllib.request
import zlib
from pathlib import Path


def make_solid_png(width: int, height: int, rgba: tuple[int, int, int, int]) -> bytes:
    raw_rows = b"".join(b"\x00" + bytes(rgba) * width for _ in range(height))

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack("!I", len(data)) + tag + data + struct.pack("!I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack("!IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw_rows, 9)) + chunk(b"IEND", b"")


def ensure_valid_assets(frontend_dir: Path) -> None:
    images_dir = frontend_dir / "assets" / "images"
    images_dir.mkdir(parents=True, exist_ok=True)
    png_512 = make_solid_png(512, 512, (5, 150, 105, 255))
    for name in ("icon.png", "adaptive-icon.png", "favicon.png", "splash-image.png"):
        target = images_dir / name
        if not target.exists() or target.stat().st_size < 100:
            target.write_bytes(png_512)

    fonts_dir = frontend_dir / "assets" / "fonts"
    fonts_dir.mkdir(parents=True, exist_ok=True)
    cairo = fonts_dir / "Cairo.ttf"
    if not cairo.exists() or cairo.stat().st_size < 1000:
        url = "https://raw.githubusercontent.com/google/fonts/main/ofl/cairo/Cairo%5Bslnt%2Cwght%5D.ttf"
        urllib.request.urlretrieve(url, str(cairo))


def configure_release_signing(frontend_dir: Path) -> None:
    android_dir = frontend_dir / "android"
    gradle_props = android_dir / "gradle.properties"
    if gradle_props.exists():
        props = gradle_props.read_text(encoding="utf-8")
        props = props.replace("-Xmx2048m", "-Xmx4096m").replace("-XX:MaxMetaspaceSize=512m", "-XX:MaxMetaspaceSize=1024m")
        gradle_props.write_text(props, encoding="utf-8")

    app_dir = android_dir / "app"
    keystore = app_dir / "upload-keystore.jks"
    if not keystore.exists():
        subprocess.run(
            [
                "keytool", "-genkeypair",
                "-keystore", str(keystore),
                "-alias", "khadamat_key",
                "-keyalg", "RSA",
                "-keysize", "2048",
                "-validity", "10000",
                "-storepass", "Khadamat2026!",
                "-keypass", "Khadamat2026!",
                "-dname", "CN=KHADAMAT Official, OU=Engineering, O=KHADAMAT, L=Mansoura, S=Dakahlia, C=EG",
            ],
            check=True,
        )

    gradle_groovy = app_dir / "build.gradle"
    if gradle_groovy.exists():
        text = gradle_groovy.read_text(encoding="utf-8")
        if 'storeFile file("upload-keystore.jks")' not in text:
            text = text.replace(
                "signingConfigs {",
                'signingConfigs {\n        release {\n            storeFile file("upload-keystore.jks")\n            storePassword "Khadamat2026!"\n            keyAlias "khadamat_key"\n            keyPassword "Khadamat2026!"\n        }',
                1,
            )
            parts = text.split("signingConfig signingConfigs.debug")
            if len(parts) >= 3:
                text = (
                    parts[0]
                    + "signingConfig signingConfigs.debug"
                    + parts[1]
                    + "signingConfig signingConfigs.release"
                    + "signingConfig signingConfigs.debug".join(parts[2:])
                )
            elif len(parts) == 2:
                text = parts[0] + "signingConfig signingConfigs.release" + parts[1]
            gradle_groovy.write_text(text, encoding="utf-8")

    gradle_kts = app_dir / "build.gradle.kts"
    if gradle_kts.exists():
        text = gradle_kts.read_text(encoding="utf-8")
        if 'storeFile = file("upload-keystore.jks")' not in text:
            text = text.replace(
                "signingConfigs {",
                'signingConfigs {\n        create("release") {\n            storeFile = file("upload-keystore.jks")\n            storePassword = "Khadamat2026!"\n            keyAlias = "khadamat_key"\n            keyPassword = "Khadamat2026!"\n        }',
                1,
            )
            parts = text.split('signingConfig = signingConfigs.getByName("debug")')
            if len(parts) >= 3:
                text = (
                    parts[0]
                    + 'signingConfig = signingConfigs.getByName("debug")'
                    + parts[1]
                    + 'signingConfig = signingConfigs.getByName("release")'
                    + 'signingConfig = signingConfigs.getByName("debug")'.join(parts[2:])
                )
            elif len(parts) == 2:
                text = parts[0] + 'signingConfig = signingConfigs.getByName("release")' + parts[1]
            gradle_kts.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    import sys
    root = Path(__file__).resolve().parents[1]
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    if mode in ("assets", "all"):
        ensure_valid_assets(root)
    if mode in ("sign", "all"):
        configure_release_signing(root)