import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import urlsplit, urlunsplit


ANDROID_ABIS = ("arm64-v8a", "armeabi-v7a", "x86_64")


def add_android_apks(manifest_path, artifact_directory):
    manifest_path = Path(manifest_path)
    artifact_directory = Path(artifact_directory)
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    app = manifest["app"]
    version = app["version"]
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("Invalid release version")
    base_url = urlsplit(app["apk_url"])
    directory_url = base_url.path.rsplit("/", 1)[0]
    packages = {}
    for abi in ANDROID_ABIS:
        name = f"BookSift-android-{abi}-v{version}.apk"
        package = artifact_directory / name
        with package.open("rb") as source:
            digest = hashlib.file_digest(source, "sha256").hexdigest()
        packages[abi] = {
            "file_name": name,
            "url": urlunsplit(base_url._replace(path=f"{directory_url}/{name}")),
            "sha256": digest,
            "size": package.stat().st_size,
        }
    app["android_apks"] = packages
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def verify_apks(artifact_directory, pubspec_path):
    pubspec = Path(pubspec_path).read_text(encoding="utf-8")
    match = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", pubspec, re.MULTILINE)
    if match is None:
        raise ValueError("Missing release version and build number")
    version, build_number = match.groups()
    sdk = Path(os.environ.get("ANDROID_HOME") or os.environ["ANDROID_SDK_ROOT"])
    tools = sorted(
        (sdk / "build-tools").glob("*/aapt"),
        key=lambda tool: tuple(int(number) for number in re.findall(r"\d+", tool.parent.name)),
    )
    if not tools:
        raise FileNotFoundError("Android SDK aapt is required")
    for abi in (None, *ANDROID_ABIS):
        suffix = "" if abi is None else f"-{abi}"
        name = f"BookSift-android{suffix}-v{version}.apk"
        badging = subprocess.check_output(
            [str(tools[-1]), "dump", "badging", str(Path(artifact_directory) / name)],
            text=True,
        )
        package = re.search(r"^package:.*$", badging, re.MULTILINE)
        native = re.search(r"^native-code:\s*(.*)$", badging, re.MULTILINE)
        if package is None or native is None:
            raise ValueError(f"Missing APK metadata: {name}")
        attributes = dict(re.findall(r"(\w+)='([^']*)'", package[0]))
        expected_abis = set(ANDROID_ABIS) if abi is None else {abi}
        if (
            attributes.get("name") != "com.linyuan.booksift"
            or attributes.get("versionCode") != build_number
            or attributes.get("versionName") != version
            or set(re.findall(r"'([^']+)'", native[1])) != expected_abis
        ):
            raise ValueError(f"APK identity, version or ABI mismatch: {name}")
        print(f"Verified {name}: versionCode={build_number}")


if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "--verify-apks":
        verify_apks(sys.argv[2], sys.argv[3])
    elif len(sys.argv) == 3:
        add_android_apks(sys.argv[1], sys.argv[2])
    else:
        raise SystemExit(
            "Usage: android_release_manifest.py <version.json> <artifacts>\n"
            "       android_release_manifest.py --verify-apks <artifacts> <pubspec.yaml>"
        )
