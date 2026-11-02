import Foundation
import Security
import UIKit

/// Everything the "Add bank message" Shortcuts action needs, kept outside Flutter so it works when the app is not
/// running: the app's own ingest token (Keychain), a small offline queue (UserDefaults) and the upload itself.
/// The Flutter side only provisions / clears the credentials through the "spending_tracker/capture" channel.
final class CaptureStore {
  static let shared = CaptureStore()

  private let service = "spending_tracker.capture"
  private let account = "credentials"
  private let pendingKey = "capture.pending"
  private let maxPending = 200
  private let lock = NSLock()

  struct Credentials: Codable {
    let url: String
    let token: String
  }

  struct Pending: Codable {
    let sender: String
    let body: String
    let receivedAt: String
  }

  enum Outcome {
    case sent  // the server took it (or it was a duplicate)
    case dropped  // the server will never accept it (bad input): do not retry
    case retry  // offline, rate limited, server trouble or an invalid token: keep it
  }

  // MARK: Credentials (Keychain)

  func saveCredentials(url: String, token: String) {
    guard let data = try? JSONEncoder().encode(Credentials(url: url, token: token)) else { return }
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(query as CFDictionary)
    var add = query
    add[kSecValueData as String] = data
    // Readable after the first unlock so a Shortcut can run while the phone is locked; never leaves this device.
    add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    SecItemAdd(add as CFDictionary, nil)
  }

  func clearCredentials() {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(query as CFDictionary)
    // A different person may sign in next: their phone must not upload the previous user's queue.
    UserDefaults.standard.removeObject(forKey: pendingKey)
  }

  func credentials() -> Credentials? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data
    else { return nil }
    return try? JSONDecoder().decode(Credentials.self, from: data)
  }

  // MARK: Queue

  func pendingCount() -> Int { loadPending().count }

  private func loadPending() -> [Pending] {
    guard let data = UserDefaults.standard.data(forKey: pendingKey) else { return [] }
    return (try? JSONDecoder().decode([Pending].self, from: data)) ?? []
  }

  private func savePending(_ items: [Pending]) {
    let capped = Array(items.suffix(maxPending))
    if let data = try? JSONEncoder().encode(capped) {
      UserDefaults.standard.set(data, forKey: pendingKey)
    }
  }

  private func enqueue(_ item: Pending) {
    lock.lock()
    defer { lock.unlock() }
    savePending(loadPending() + [item])
  }

  private func remove(_ item: Pending) {
    lock.lock()
    defer { lock.unlock() }
    var items = loadPending()
    if let i = items.firstIndex(where: {
      $0.sender == item.sender && $0.body == item.body && $0.receivedAt == item.receivedAt
    }) {
      items.remove(at: i)
      savePending(items)
    }
  }

  // MARK: Upload

  /// Queues first, then tries to send: a message is never lost to a crash or a bad connection.
  /// Returns false when the phone has no credentials yet (the app has not been opened since installing).
  @discardableResult
  func submit(sender: String, body: String) async -> Bool {
    let item = Pending(sender: sender, body: body, receivedAt: Self.iso(Date()))
    enqueue(item)
    guard credentials() != nil else { return false }
    await flush()
    return true
  }

  /// Sends the queue in order. Stops at the first message that should be retried later.
  func flush() async {
    guard let creds = credentials() else { return }
    for item in loadPending() {
      switch await send(item, creds) {
      case .sent, .dropped:
        remove(item)
      case .retry:
        return
      }
    }
  }

  private func send(_ item: Pending, _ creds: Credentials) async -> Outcome {
    guard let url = URL(string: creds.url + "/functions/v1/ingest") else { return .dropped }
    var request = URLRequest(url: url, timeoutInterval: 20)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "content-type")
    request.setValue(creds.token, forHTTPHeaderField: "x-ingest-token")
    let payload: [String: String] = [
      "sender": item.sender, "body": item.body, "received_at": item.receivedAt,
    ]
    guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return .dropped }
    request.httpBody = body
    do {
      let (_, response) = try await URLSession.shared.data(for: request)
      guard let http = response as? HTTPURLResponse else { return .retry }
      switch http.statusCode {
      case 200..<300: return .sent
      case 400, 413, 422: return .dropped
      default: return .retry  // 401 (token revoked: the app re-provisions on next open), 429, 5xx
      }
    } catch {
      return .retry
    }
  }

  static func iso(_ date: Date) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f.string(from: date)
  }
}
