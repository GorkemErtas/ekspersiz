import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "ekspersiz/installation",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "directory" else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        let support = try FileManager.default.url(
          for: .applicationSupportDirectory, in: .userDomainMask,
          appropriateFor: nil, create: true
        )
        var directory = support.appendingPathComponent("installation", isDirectory: true)
        try FileManager.default.createDirectory(
          at: directory, withIntermediateDirectories: true
        )
        // Exclude the directory before Dart creates or replaces any marker in it.
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        result(directory.path)
      } catch {
        result(FlutterError(
          code: "STORAGE_UNAVAILABLE", message: "Yerel tercih kaydedilemedi.", details: nil
        ))
      }
    }
  }
}
