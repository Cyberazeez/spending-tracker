import AppIntents
import Foundation

/// The Shortcuts action "Add bank message". A personal automation "When I get a message from <bank>" runs a
/// shortcut that calls this with the sender and the text; it needs no token pasted by hand.
@available(iOS 16.0, *)
struct AddBankMessageIntent: AppIntent {
  static let title: LocalizedStringResource = "Add bank message"
  static let description = IntentDescription(
    "Sends a bank SMS to your Halala so the purchase is recorded.")
  static var openAppWhenRun: Bool = false

  @Parameter(title: "Sender")
  var sender: String

  @Parameter(title: "Message")
  var message: String

  static var parameterSummary: some ParameterSummary {
    Summary("Add \(\.$message) from \(\.$sender)")
  }

  func perform() async throws -> some IntentResult {
    let stored = await CaptureStore.shared.submit(sender: sender, body: message)
    if !stored {
      // Queued, but there is no token yet: tell the person what to do instead of failing silently.
      throw CaptureError.notSetUp
    }
    return .result()
  }
}

@available(iOS 16.0, *)
enum CaptureError: Error, CustomLocalizedStringResourceConvertible {
  case notSetUp

  var localizedStringResource: LocalizedStringResource {
    switch self {
    case .notSetUp:
      return "Open Halala once and sign in. The message is saved and will be sent then."
    }
  }
}
