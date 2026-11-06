import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from android_release_manifest import ANDROID_ABIS, add_android_apks, verify_apks


class AndroidReleaseManifestTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.manifest_path = self.directory / "version.json"
        self.original = {
            "app": {
                "version": "1.2.3",
                "version_code": 5,
                "apk_url": "https://github.com/owner/repo/releases/download/v1.2.3/BookSift-android-v1.2.3.apk",
                "apk_sha256": "a" * 64,
                "windows_sha256": "b" * 64,
            },
            "seed": {"basic_version": 4},
        }
        self.manifest_path.write_text(json.dumps(self.original), encoding="utf-8")
        for abi in ANDROID_ABIS:
            (self.directory / f"BookSift-android-{abi}-v1.2.3.apk").write_bytes(abi.encode())

    def test_hashes_actual_packages_without_creating_sidecars(self):
        add_android_apks(self.manifest_path, self.directory)
        manifest = json.loads(self.manifest_path.read_text(encoding="utf-8"))
        packages = manifest["app"].pop("android_apks")
        self.assertEqual(manifest, self.original)
        self.assertEqual(set(packages), set(ANDROID_ABIS))
        for abi, package in packages.items():
            self.assertEqual(package["sha256"], hashlib.sha256(abi.encode()).hexdigest())
            self.assertEqual(package["size"], len(abi.encode()))
            self.assertEqual(package["file_name"], f"BookSift-android-{abi}-v1.2.3.apk")
            self.assertEqual(
                package["url"],
                self.original["app"]["apk_url"].replace("android-v", f"android-{abi}-v"),
            )
        self.assertEqual(list(self.directory.glob("*.sha256")), [])

    def test_missing_package_does_not_write_partial_manifest(self):
        original_bytes = self.manifest_path.read_bytes()
        (self.directory / "BookSift-android-x86_64-v1.2.3.apk").unlink()
        with self.assertRaises(FileNotFoundError):
            add_android_apks(self.manifest_path, self.directory)
        self.assertEqual(self.manifest_path.read_bytes(), original_bytes)

    def test_verifier_rejects_abi_version_offsets_and_wrong_architectures(self):
        pubspec = self.directory / "pubspec.yaml"
        pubspec.write_text("version: 1.2.3+5\n", encoding="utf-8")
        aapt = self.directory / "build-tools" / "36.0.0" / "aapt"
        aapt.parent.mkdir(parents=True)
        aapt.touch()

        def metadata(arguments, **kwargs):
            name = Path(arguments[-1]).name
            architectures = next(
                ([abi] for abi in ANDROID_ABIS if f"-{abi}-" in name), list(ANDROID_ABIS)
            )
            return (
                "package: name='com.linyuan.booksift' versionCode='5' versionName='1.2.3'\n"
                + "native-code: " + " ".join(f"'{abi}'" for abi in architectures) + "\n"
            )

        with patch.dict(os.environ, {"ANDROID_HOME": str(self.directory)}):
            with patch("android_release_manifest.subprocess.check_output", side_effect=metadata) as call:
                verify_apks(self.directory, pubspec)
                self.assertEqual(call.call_count, 4)
            for old, replacement in (
                ("versionCode='5'", "versionCode='2005'"),
                ("'arm64-v8a'", "'x86'"),
                ("'arm64-v8a'", "'arm64-v8a' 'x86_64'"),
            ):
                def invalid_metadata(arguments, **kwargs):
                    result = metadata(arguments, **kwargs)
                    return result.replace(old, replacement) if "-arm64-v8a-" in arguments[-1] else result

                with patch("android_release_manifest.subprocess.check_output", side_effect=invalid_metadata):
                    with self.assertRaises(ValueError):
                        verify_apks(self.directory, pubspec)


if __name__ == "__main__":
    unittest.main()
