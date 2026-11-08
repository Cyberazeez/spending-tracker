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

  /// Older builds kept the widget token in the App Group's UserDefaults; remove it wherever it is found.
  private func removeLegacyWidgetCredentials(_ defaults: UserDefaults?) {
    for key in ["widget.url", "widget.token", "widget.user"] {
      defaults?.removeObject(forKey: key)
    }
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
      let defaults = UserDefaults(suiteName: "group.com.cyberazeez.spendingtracker")
      switch call.method {
      case "save":
        guard let values = call.arguments as? [String: Any] else {
          result(FlutterMethodNotImplemented)
          return
        }
        for (key, value) in values {
          if value is NSNull {
            defaults?.removeObject(forKey: key)
          } else {
            defaults?.set(value, forKey: key)
          }
        }
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)
      // The widget fetches its own numbers with a read-only token (kind "widget", only good for widget-summary).
      case "saveCredentials":
        guard let args = call.arguments as? [String: Any],
          let url = args["url"] as? String,
          let token = args["token"] as? String,
          let userId = args["userId"] as? String
        else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard WidgetKeychain.save(WidgetKeychain.Credentials(url: url, token: token, userId: userId)) else {
          // Not stored (for example before the first unlock): Dart retries on the next resume.
          result(FlutterError(code: "keychain", message: "could not store the widget token", details: nil))
          return
        }
        removeLegacyWidgetCredentials(defaults)
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)
      case "clearCredentials":
        WidgetKeychain.clear()
        removeLegacyWidgetCredentials(defaults)
        for key in ["today", "month", "budget", "updated"] {
          defaults?.removeObject(forKey: key)
        }
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)
      case "credentialsStatus":
        // A token an older build left in the App Group's UserDefaults is deleted here (the app then fetches a new one
        // into the Keychain), so no copy stays readable in the plain file.
        removeLegacyWidgetCredentials(defaults)
        let stored = WidgetKeychain.load()
        result([
          "hasToken": stored != nil,
          "userId": stored?.userId as Any,
        ])
      default:
        result(FlutterMethodNotImplemented)
      }
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
      case "openShortcuts":
        if let url = URL(string: "shortcuts://") {
          UIApplication.shared.open(url, options: [:]) { _ in result(nil) }
        } else {
          result(nil)
        }
      case "status":
        let creds = store.credentials()
        result([
          "hasToken": creds != nil, "userId": creds?.userId as Any, "pending": store.pendingCount(), "last": store.lastResult(),
        ])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// The widget's read-only token lives in the Keychain, in an access group shared by the app and the widget extension
/// (not in the App Group's UserDefaults, which is a plain file any process with the group can read and which is
/// included in unencrypted-backup tooling). The group name comes from Info.plist (`SharedKeychainGroup`, expanded
/// from $(AppIdentifierPrefix) at build time). The same helper exists in the other target (they cannot share a file
/// without a project change); keep both in step.
enum WidgetKeychain {
  struct Credentials: Codable {
    let url: String
    let token: String
    let userId: String
  }

  private static let service = "spending_tracker.widget"
  private static let account = "credentials"

  private static func baseQuery() -> [String: Any]? {
    guard let group = Bundle.main.object(forInfoDictionaryKey: "SharedKeychainGroup") as? String,
      !group.isEmpty, !group.contains("$(")
    else { return nil }
    return [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecAttrAccessGroup as String: group,
    ]
  }

  @discardableResult
  static func save(_ credentials: Credentials) -> Bool {
    guard var query = baseQuery(), let data = try? JSONEncoder().encode(credentials) else { return false }
    SecItemDelete(query as CFDictionary)
    query[kSecValueData as String] = data
    // Readable after the first unlock so a refresh can run while the phone is locked; never leaves this device.
    query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    if SecItemAdd(query as CFDictionary, nil) == errSecSuccess { return true }
    SecItemDelete(baseQuery()! as CFDictionary)  // leave no half state
    return false
  }

  static func load() -> Credentials? {
    guard var query = baseQuery() else { return nil }
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else {
      return nil
    }
    return try? JSONDecoder().decode(Credentials.self, from: data)
  }

  static func clear() {
    if let query = baseQuery() { SecItemDelete(query as CFDictionary) }
  }
}
