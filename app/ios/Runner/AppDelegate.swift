import Flutter
import UIKit
import UserNotifications
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
    registerReminderBridge(engineBridge)
    registerCaptureBridge(engineBridge)
    // Messages queued by the Shortcuts action are sent whenever the app becomes active.
    NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { _ in Task { await CaptureStore.shared.flush() } }
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

  /// Bill reminders as local notifications ("spending_tracker/reminders"): the app sends the full list each time and
  /// we replace everything we scheduled before. They fire at the given moment even if the app is closed.
  private func registerReminderBridge(_ engineBridge: FlutterImplicitEngineBridge) {
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SpendingReminderBridge") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "spending_tracker/reminders",
      binaryMessenger: registrar.messenger()
    )
    let prefix = "rem."
    channel.setMethodCallHandler { call, result in
      let center = UNUserNotificationCenter.current()
      switch call.method {
      case "requestPermission":
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
          DispatchQueue.main.async { result(granted) }
        }
      case "clear":
        center.getPendingNotificationRequests { pending in
          let ours = pending.map { $0.identifier }.filter { $0.hasPrefix(prefix) }
          center.removePendingNotificationRequests(withIdentifiers: ours)
          DispatchQueue.main.async { result(nil) }
        }
      case "replace":
        guard let args = call.arguments as? [String: Any],
          let items = args["items"] as? [[String: Any]]
        else {
          result(FlutterMethodNotImplemented)
          return
        }
        center.getPendingNotificationRequests { pending in
          let ours = pending.map { $0.identifier }.filter { $0.hasPrefix(prefix) }
          center.removePendingNotificationRequests(withIdentifiers: ours)
          var riyadh = Calendar(identifier: .gregorian)
          riyadh.timeZone = TimeZone(identifier: "Asia/Riyadh") ?? TimeZone.current
          for item in items {
            guard let id = item["id"] as? String,
              let title = item["title"] as? String,
              let body = item["body"] as? String,
              let at = item["at"] as? NSNumber
            else { continue }
            let date = Date(timeIntervalSince1970: at.doubleValue)
            if date <= Date() { continue }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            var parts = riyadh.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            parts.timeZone = riyadh.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            center.add(UNNotificationRequest(identifier: prefix + id, content: content, trigger: trigger))
          }
          DispatchQueue.main.async { result(nil) }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Credentials and queue for the "Add bank message" Shortcuts action ("spending_tracker/capture").
  private func registerCaptureBridge(_ engineBridge: FlutterImplicitEngineBridge) {
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SpendingCaptureBridge") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "spending_tracker/capture",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      let store = CaptureStore.shared
      switch call.method {
      case "saveCredentials":
        guard let args = call.arguments as? [String: Any],
          let url = args["url"] as? String,
          let token = args["token"] as? String,
          let userId = args["userId"] as? String
        else {
          result(FlutterMethodNotImplemented)
          return
        }
        store.saveCredentials(url: url, token: token, userId: userId)
        result(nil)
      case "clearCredentials":
        store.clearCredentials()
        result(nil)
      case "flush":
        Task { @MainActor in
          await store.flush()
          result(nil)
        }
      case "status":
        let creds = store.credentials()
        result([
          "hasToken": creds != nil, "userId": creds?.userId as Any, "pending": store.pendingCount(),
        ])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
