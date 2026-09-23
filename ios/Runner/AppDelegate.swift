import Flutter
import UIKit
import UserNotifications
import AuthenticationServices

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let appleSignIn = AppleSignInCoordinator()
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Required for local and push notifications on iOS
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BinaryAppleAuth") else {
      return
    }
    let channel = FlutterMethodChannel(name: "org.binaryapp/apple-auth", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "signIn" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let self = self else {
        result(FlutterError(code: "auth-unavailable", message: "Sign-in is unavailable.", details: nil))
        return
      }
      self.appleSignIn.signIn(arguments: call.arguments, result: result)
    }
  }
}

/// Keep the sheet, callback and scene anchor alive until Apple completes.
/// No credential is logged or persisted by this bridge.
private final class AppleSignInCoordinator: NSObject,
    ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
  private var completion: FlutterResult?
  private var anchor: UIWindow?
  private var controller: ASAuthorizationController?

  func signIn(arguments: Any?, result: @escaping FlutterResult) {
    guard completion == nil else {
      result(FlutterError(code: "sign-in-in-progress", message: "Finish the current sign-in first.", details: nil))
      return
    }
    guard let args = arguments as? [String: Any], let nonce = args["nonce"] as? String, !nonce.isEmpty else {
      result(FlutterError(code: "missing-nonce", message: "Could not start a secure sign-in.", details: nil))
      return
    }
    let activeWindow = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    guard let window = activeWindow else {
      result(FlutterError(code: "no-active-window", message: "Return to the app and try again.", details: nil))
      return
    }
    completion = result
    anchor = window
    let request = ASAuthorizationAppleIDProvider().createRequest()
    request.nonce = nonce
    if args["requestProfile"] as? Bool == true {
      request.requestedScopes = [.fullName, .email]
    }
    let authorization = ASAuthorizationController(authorizationRequests: [request])
    controller = authorization
    authorization.delegate = self
    authorization.presentationContextProvider = self
    authorization.performRequests()
  }

  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    // Set before performRequests and retained for the lifetime of this request.
    // Never force-unwrap: a nil here is a Swift trap that kills the app with no
    // catchable error. A bare anchor still lets the system present the sheet.
    return anchor ?? ASPresentationAnchor()
  }

  func authorizationController(controller: ASAuthorizationController,
                               didCompleteWithAuthorization authorization: ASAuthorization) {
    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
          let token = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }),
          let code = credential.authorizationCode.flatMap({ String(data: $0, encoding: .utf8) }) else {
      finish(FlutterError(code: "missing-identity-token", message: "Apple returned an incomplete credential.", details: nil))
      return
    }
    var values: [String: Any] = [
      "identityToken": token, "authorizationCode": code, "userIdentifier": credential.user
    ]
    if let email = credential.email { values["email"] = email }
    if let given = credential.fullName?.givenName { values["givenName"] = given }
    if let family = credential.fullName?.familyName { values["familyName"] = family }
    finish(values)
  }

  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    let nativeError = error as NSError
    let cancelled = nativeError.domain == ASAuthorizationError.errorDomain &&
      nativeError.code == ASAuthorizationError.canceled.rawValue
    finish(FlutterError(code: cancelled ? "canceled" : "apple-authorization-\(nativeError.code)",
                        message: error.localizedDescription, details: nil))
  }

  private func finish(_ value: Any?) {
    let callback = completion
    completion = nil
    controller = nil
    anchor = nil
    callback?(value)
  }
}
