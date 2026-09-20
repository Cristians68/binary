import Flutter

// google_sign_in_ios now registers its own scene lifecycle delegate. Let
// Flutter deliver each callback once, including URLs from a cold launch.
class SceneDelegate: FlutterSceneDelegate {}
