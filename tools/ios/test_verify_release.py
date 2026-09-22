from copy import deepcopy
import json
import re
from pathlib import Path
import plistlib
import tempfile
import unittest
import zipfile

from verify_release import release_settings, stamp_source, verify_ipa


class ReleaseVerificationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.ipa = Path(self.temp.name) / "Binary.ipa"
        self.revision = "a" * 40
        self.settings = {
            "appId": "1:123:ios:abc", "iosClientId": "123-client.apps.googleusercontent.com",
            "iosBundleId": "org.example.binary", "version": "1.0.2",
            "googlePlugin": "6.3.3", "googleSDK": "9.0.0",
        }
        self.info = {
            "CFBundleIdentifier": "org.example.binary", "CFBundleShortVersionString": "1.0.2",
            "CFBundleVersion": "55", "GIDClientID": self.settings["iosClientId"],
            "BinarySourceRevision": self.revision,
            "BinaryGoogleSignInPluginVersion": "6.3.3", "BinaryGoogleSignInSDKVersion": "9.0.0",
            "CFBundleURLTypes": [{"CFBundleURLSchemes": [
                "com.googleusercontent.apps.123-client", "app-1-123-ios-abc"]}],
        }

    def archive(self, info, service=None):
        with zipfile.ZipFile(self.ipa, "w") as archive:
            archive.writestr("Payload/Runner.app/Info.plist",
                             plistlib.dumps(info, fmt=plistlib.FMT_BINARY))
            if service is not None:
                archive.writestr("Payload/Runner.app/GoogleService-Info.plist", plistlib.dumps(service))

    def verify(self):
        return verify_ipa(self.ipa, self.settings, self.revision, "55")

    def test_valid_binary_plist_produces_a_build_identity(self):
        self.archive(self.info)
        report = self.verify()
        self.assertEqual(report["BinarySourceRevision"], self.revision)
        self.assertEqual(report["CFBundleVersion"], "55")

    def test_archive_overrides_cannot_hide_behind_correct_source(self):
        for key in ("GIDClientID", "CFBundleIdentifier", "CFBundleShortVersionString",
                    "CFBundleVersion", "BinarySourceRevision", "BinaryGoogleSignInPluginVersion",
                    "BinaryGoogleSignInSDKVersion"):
            with self.subTest(key=key):
                info = {**self.info, key: "stale"}
                self.archive(info)
                with self.assertRaisesRegex(ValueError, key):
                    self.verify()

    def test_each_auth_callback_must_survive_packaging(self):
        for missing in (0, 1):
            with self.subTest(missing=missing):
                info = deepcopy(self.info)
                del info["CFBundleURLTypes"][0]["CFBundleURLSchemes"][missing]
                self.archive(info)
                with self.assertRaisesRegex(ValueError, "callback scheme"):
                    self.verify()

    def test_conflicting_bundled_firebase_config_is_rejected(self):
        service = {"CLIENT_ID": "wrong", "BUNDLE_ID": self.settings["iosBundleId"],
                   "GOOGLE_APP_ID": self.settings["appId"]}
        self.archive(self.info, service)
        with self.assertRaisesRegex(ValueError, "conflicting CLIENT_ID"):
            self.verify()

    def test_matching_bundled_firebase_config_is_accepted(self):
        self.archive(self.info, {"CLIENT_ID": self.settings["iosClientId"],
                                 "BUNDLE_ID": self.settings["iosBundleId"],
                                 "GOOGLE_APP_ID": self.settings["appId"]})
        self.verify()

    def test_unstamped_old_build_is_rejected(self):
        info = self.info.copy()
        del info["BinarySourceRevision"]
        self.archive(info)
        with self.assertRaisesRegex(ValueError, "BinarySourceRevision"):
            self.verify()

    def test_real_project_config_and_lockfile_can_be_stamped(self):
        root = Path(__file__).resolve().parents[2]
        fixture = Path(self.temp.name)
        for name in ("lib/firebase_options.dart", "pubspec.yaml", "pubspec.lock", "ios/Runner/Info.plist"):
            target = fixture / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((root / name).read_bytes())
        (fixture / "ios/Podfile.lock").write_text("PODS:\n  - GoogleSignIn (9.0.0):\n", encoding="utf-8")
        plugins = fixture / ".flutter-plugins-dependencies"
        plugins.write_text(json.dumps({"swift_package_manager_enabled": {"ios": False}}),
                           encoding="utf-8")
        settings = release_settings(fixture)
        stamp_source(fixture, settings, self.revision)
        with (fixture / "ios/Runner/Info.plist").open("rb") as stream:
            info = plistlib.load(stream)
        info.update(CFBundleIdentifier=settings["iosBundleId"],
                    CFBundleShortVersionString=settings["version"], CFBundleVersion="55")
        self.archive(info)
        verify_ipa(self.ipa, settings, self.revision, "55")
        for unexpected in (True, None):
            plugins.write_text(json.dumps({"swift_package_manager_enabled": {"ios": unexpected}}),
                               encoding="utf-8")
            with self.subTest(swift_package_manager=unexpected):
                with self.assertRaisesRegex(ValueError, "CocoaPods"):
                    release_settings(fixture)
        plugins.write_text(json.dumps({"swift_package_manager_enabled": {"ios": False}}),
                           encoding="utf-8")
        # Downgrade whatever google_sign_in_ios actually resolved to, rather
        # than a hard-coded version: pinning one here made this check quietly
        # stop testing anything the first time the plugin was upgraded.
        lock = fixture / "pubspec.lock"
        original = lock.read_text(encoding="utf-8")
        downgraded = re.sub(
            r'(^  google_sign_in_ios:\n(?:.*\n)*?    version: ")[\d.]+(")',
            r'\g<1>5.9.0\g<2>', original, count=1, flags=re.M)
        self.assertNotEqual(downgraded, original,
                            "the simulated downgrade must actually edit the lockfile")
        lock.write_text(downgraded, encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "predates"):
            release_settings(fixture)


if __name__ == "__main__":
    unittest.main()
