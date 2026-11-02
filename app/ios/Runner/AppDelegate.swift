import Flutter
import UIKit
import WidgetKit

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
    registerWidgetBridge(engineBridge)
  }

  /// Dart saves the widget's numbers here ("spending_tracker/widget" / "save"): they go into the shared App Group
  /// that the widget extension reads, then the widget is asked to redraw.
  private func registerWidgetBridge(_ engineBridge: FlutterImplicitEngineBridge) {
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SpendingWidgetBridge") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "spending_tracker/widget",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "save", let values = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented)
        return
      }
      let defaults = UserDefaults(suiteName: "group.com.cyberazeez.spendingtracker")
      for (key, value) in values {
        if value is NSNull {
          defaults?.removeObject(forKey: key)
        } else {
          defaults?.set(value, forKey: key)
        }
      }
      WidgetCenter.shared.reloadAllTimelines()
      result(nil)
    }
  }
}
