"""Check the exported IPA before TestFlight upload. Uses only the standard library."""

import argparse
import json
from pathlib import Path
import plistlib
import re
import shutil
import sys
import zipfile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def match(pattern, text, description):
    found = re.search(pattern, text, re.MULTILINE)
    require(found is not None, f"Missing {description}")
    return found.group(1)


def release_settings(root):
    plugins = json.loads((root / ".flutter-plugins-dependencies").read_text(encoding="utf-8"))
    require(plugins.get("swift_package_manager_enabled", {}).get("ios") is False,
            "Expected the project's CocoaPods integration; Swift Package Manager must be disabled")
    options = (root / "lib/firebase_options.dart").read_text(encoding="utf-8")
    ios = match(r"static const FirebaseOptions ios = FirebaseOptions\(([\s\S]*?)\);",
                options, "iOS Firebase options")
    settings = {
        key: match(rf"{key}:\s*'([^']+)'", ios, f"iOS {key}")
        for key in ("appId", "iosClientId", "iosBundleId")
    }
    settings["version"] = match(
        r"^version:\s*([^+\s]+)", (root / "pubspec.yaml").read_text(encoding="utf-8"),
        "app version")
    lock = (root / "pubspec.lock").read_text(encoding="utf-8")
    package = match(r"^  google_sign_in_ios:\n([\s\S]*?)(?=^  \w+:|\Z)",
                    lock, "resolved Google iOS plugin")
    settings["googlePlugin"] = match(r'^    version: "([\d.]+)"', package, "Google plugin version")
    pods = (root / "ios/Podfile.lock").read_text(encoding="utf-8")
    settings["googleSDK"] = match(r"^  - GoogleSignIn \(([\d.]+)\)", pods, "Google iOS SDK")
    require(tuple(map(int, settings["googlePlugin"].split("."))) >= (6, 3, 3),
            "The resolved Google iOS plugin predates the scene/configuration fixes")
    require(tuple(map(int, settings["googleSDK"].split("."))) >= (9, 0, 0),
            "The resolved native Google SDK is older than expected")
    # A native iOS termination -- a Swift fatalError, an uncaught NSException,
    # a signal -- is invisible to every Dart handler in this app. Shipping a
    # release without a native crash handler is how one Google sign-in crash
    # survived five build cycles with no evidence beyond "it closed".
    crash = match(r"^  firebase_crashlytics:\n([\s\S]*?)(?=^  \w+:|\Z)",
                  lock, "resolved Crashlytics plugin "
                  "(an iOS release must be able to report native crashes)")
    settings["crashlytics"] = match(r'^    version: "([\d.]+)"', crash,
                                    "Crashlytics version")
    return settings


def stamp_source(root, settings, revision):
    source = root / "ios/Runner/Info.plist"
    with source.open("rb") as stream:
        info = plistlib.load(stream)
    info.update({
        "BinarySourceRevision": revision,
        "BinaryGoogleSignInPluginVersion": settings["googlePlugin"],
        "BinaryGoogleSignInSDKVersion": settings["googleSDK"],
    })
    with source.open("wb") as stream:
        plistlib.dump(info, stream, sort_keys=False)


def verify_ipa(ipa, settings, revision, build_number):
    with zipfile.ZipFile(ipa) as archive:
        infos = [name for name in archive.namelist()
                 if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", name)]
        require(len(infos) == 1, "Expected exactly one app Info.plist in the IPA")
        info = plistlib.loads(archive.read(infos[0]))
        expected = {
            "CFBundleIdentifier": settings["iosBundleId"],
            "CFBundleShortVersionString": settings["version"],
            "CFBundleVersion": str(build_number),
            "GIDClientID": settings["iosClientId"],
            "BinarySourceRevision": revision,
            "BinaryGoogleSignInPluginVersion": settings["googlePlugin"],
            "BinaryGoogleSignInSDKVersion": settings["googleSDK"],
        }
        for key, value in expected.items():
            require(info.get(key) == value, f"Exported IPA has unexpected or missing {key}")
        schemes = {scheme for item in info.get("CFBundleURLTypes", [])
                   for scheme in item.get("CFBundleURLSchemes", [])}
        reversed_client = ".".join(reversed(settings["iosClientId"].split(".")))
        firebase_callback = "app-" + settings["appId"].replace(":", "-")
        require(reversed_client in schemes, "IPA is missing the native Google callback scheme")
        require(firebase_callback in schemes, "IPA is missing the Firebase fallback callback scheme")
        service_path = infos[0].removesuffix("Info.plist") + "GoogleService-Info.plist"
        if service_path in archive.namelist():
            service = plistlib.loads(archive.read(service_path))
            for key, value in {"CLIENT_ID": settings["iosClientId"],
                               "BUNDLE_ID": settings["iosBundleId"],
                               "GOOGLE_APP_ID": settings["appId"]}.items():
                require(service.get(key) == value,
                        f"Bundled GoogleService-Info.plist has a conflicting {key}")
        return {**expected, "callbackSchemes": sorted(schemes), "ipa": ipa.name}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--revision", required=True)
    parser.add_argument("--stamp", action="store_true")
    parser.add_argument("--build-number")
    args = parser.parse_args()
    require(re.fullmatch(r"[0-9a-f]{40}", args.revision), "Expected the full Git source revision")
    settings = release_settings(args.root)
    if args.stamp:
        stamp_source(args.root, settings, args.revision)
        print(f"Stamped iOS release source: {args.revision}")
        return
    require(args.build_number and args.build_number.isdigit(), "Expected the CI build number")
    ipas = list((args.root / "build/ios/ipa").glob("*.ipa"))
    require(len(ipas) == 1, "Expected exactly one exported IPA")
    report = verify_ipa(ipas[0], settings, args.revision, args.build_number)
    symbols = args.root / "build/ios/archive/Runner.xcarchive/dSYMs"
    if symbols.is_dir():
        shutil.make_archive(str(args.root / "build/ios/ios-symbols"), "zip",
                            root_dir=symbols.parent, base_dir="dSYMs")
    report_path = args.root / "build/ios/ios-auth-release.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, zipfile.BadZipFile, plistlib.InvalidFileException) as error:
        print(f"iOS release verification failed: {error}", file=sys.stderr)
        sys.exit(1)
