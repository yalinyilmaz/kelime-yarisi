import Flutter
import FirebaseCore
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var questionHistoryChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    #if DEBUG
      // App Check includes its debug secret in warning logs. Keep errors visible.
      FirebaseConfiguration.shared.setLoggerLevel(.error)
    #endif
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "kelime_yarisi/question_history",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    questionHistoryChannel = channel
    channel.setMethodCallHandler { call, result in
      guard call.method == "excludeFromBackup" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            let path = arguments["path"] as? String else {
        result(FlutterError(code: "invalid-path", message: "History path required", details: nil))
        return
      }
      var directory = URL(fileURLWithPath: path, isDirectory: true).resolvingSymlinksInPath()
      let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).resolvingSymlinksInPath()
      guard directory.path.hasPrefix(home.path + "/"),
            directory.lastPathComponent == "question_history" else {
        result(FlutterError(code: "invalid-path", message: "Only the app's history directory is allowed", details: nil))
        return
      }
      do {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        result(nil)
      } catch {
        result(FlutterError(code: "backup-exclusion-failed", message: error.localizedDescription, details: nil))
      }
    }
  }
}
