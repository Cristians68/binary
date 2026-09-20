import Flutter
import UIKit
import GoogleSignIn

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    // The pinned Google plugin only subscribes to AppDelegate URL events.
    // UIKit delivers these to the scene once UIApplicationSceneManifest exists.
    let unhandled = Set(URLContexts.filter {
      !GIDSignIn.sharedInstance.handle($0.url)
    })
    if !unhandled.isEmpty {
      super.scene(scene, openURLContexts: unhandled)
    }
  }
}
