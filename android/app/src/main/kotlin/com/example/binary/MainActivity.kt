package com.example.binary

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity, not FlutterActivity: local_auth (App Lock) needs a
// FragmentActivity on Android to show the biometric prompt.
class MainActivity : FlutterFragmentActivity()
