"""Sign an unsigned Android App Bundle with a known upload certificate."""

import argparse
import getpass
import hashlib
import os
from pathlib import Path
import re
import subprocess
from tempfile import TemporaryDirectory
from zipfile import BadZipFile, ZipFile


def java_tool(name):
    java_home = os.environ.get("JAVA_HOME")
    return str(Path(java_home) / "bin" / name) if java_home else name


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--keystore", required=True, type=Path)
    parser.add_argument("--alias", required=True)
    parser.add_argument("--sha256", required=True, help="Expected upload certificate fingerprint")
    args = parser.parse_args()
    expected = args.sha256.replace(":", "").lower()
    if not re.fullmatch(r"[0-9a-f]{64}", expected):
        parser.error("--sha256 must be a SHA-256 certificate fingerprint")
    if args.bundle.suffix != ".aab" or args.output.suffix != ".aab" or args.output.exists():
        parser.error("provide an input .aab and a new output .aab path")

    try:
        with ZipFile(args.bundle) as bundle:
            names = bundle.namelist()
            if "base/manifest/AndroidManifest.xml" not in names:
                parser.error("the input does not contain an Android App Bundle manifest")
            if any(re.fullmatch(r"META-INF/[^/]+\.(SF|RSA|DSA|EC)", name, re.I) for name in names):
                parser.error("the input is already signed. Build a fresh unsigned bundle")

        env = os.environ.copy()
        store_var = "KHADAMAT_STORE_PASSWORD"
        key_var = "KHADAMAT_KEY_PASSWORD"
        if store_var not in env:
            env[store_var] = getpass.getpass("Keystore password: ")
        if key_var not in env:
            env[key_var] = getpass.getpass("Key password (Enter to use the keystore password): ") or env[store_var]
        store_args = ["-keystore", str(args.keystore), "-storepass:env", store_var]
        certificate = subprocess.check_output(
            [java_tool("keytool"), "-exportcert", *store_args, "-alias", args.alias],
            env=env,
        )
        if hashlib.sha256(certificate).hexdigest() != expected:
            parser.error("the keystore alias does not match the expected upload certificate")

        with TemporaryDirectory(dir=args.output.parent) as directory:
            signed = Path(directory) / args.output.name
            subprocess.run(
                [
                    java_tool("jarsigner"), *store_args, "-keypass:env", key_var,
                    "-signedjar", str(signed), str(args.bundle), args.alias,
                ],
                env=env,
                check=True,
            )
            subprocess.run(
                [java_tool("jarsigner"), "-verify", "-strict", *store_args, str(signed), args.alias],
                env=env,
                check=True,
            )
            # Publish the verified result atomically without replacing an existing bundle.
            os.link(signed, args.output)
    except (BadZipFile, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Signing failed: {error}\n")

    print(f"Verified signed bundle: {args.output}")


if __name__ == "__main__":
    main()
