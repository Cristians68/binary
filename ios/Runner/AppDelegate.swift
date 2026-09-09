import Flutter
import UIKit
import UserNotifications
import GoogleSignIn

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Required for local and push notifications on iOS
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    // Give Google Sign-In first refusal, then hand anything it does not
    // recognise to super.
    //
    // This used to `return GIDSignIn.sharedInstance.handle(url)` and stop
    // there. GIDSignIn returns false for a URL that is not its own, but by
    // then super had already been skipped — so every other callback into the
    // app (Firebase Auth's OAuth redirect, and any plugin that registers a
    // URL scheme) was answered "not handled" by an app delegate that had not
    // actually looked.
    if GIDSignIn.sharedInstance.handle(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}