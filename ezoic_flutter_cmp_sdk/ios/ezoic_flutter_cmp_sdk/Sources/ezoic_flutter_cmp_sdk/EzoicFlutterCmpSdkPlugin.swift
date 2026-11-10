import Flutter
import UIKit
#if canImport(EzoicCmpSDKBinary)
import EzoicCmpSDKBinary
#else
import EzoicCmpSDK
#endif

public class EzoicFlutterCmpSdkPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.ezoic/ezoic_flutter_cmp_sdk", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(EzoicFlutterCmpSdkPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      guard let args = call.arguments as? [String: Any],
            let domain = args["domain"] as? String, !domain.isEmpty else {
        result(FlutterError(code: "EzoicCmp", message: "initialize requires a non-empty `domain`.", details: nil))
        return
      }
      let debug = args["debugEnabled"] as? Bool ?? false
      EzoicCmp.initialize(domain: domain, configuration: EzoicCmpConfiguration(
        cmpEnabled: args["cmpEnabled"] as? Bool ?? true,
        autoReadConsent: args["autoReadConsent"] as? Bool ?? true,
        debugEnabled: debug
      ))
      result(nil)
      if args["autoPresentConsent"] as? Bool ?? true { Self.autoPresentConsent(debug: debug) }
    case "presentConsentIfRequired":
      Self.presentConsent(reopen: false) { result($0) }
    case "presentConsentSettings":
      Self.presentConsent(reopen: true) { result($0) }
    case "isConsentRequired":
      result(EzoicCmp.isConsentRequired)
    case "isPrivacyOptionsRequired":
      result(EzoicCmp.isPrivacyOptionsRequired)
    case "resetConsent":
      EzoicCmp.resetConsent()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Runs once after `initialize` when `autoPresentConsent` is on. The outcome
  /// is only logged; apps that need it call `presentConsentIfRequired`.
  private static func autoPresentConsent(debug: Bool) {
    DispatchQueue.main.async {
      guard let host = topViewController() else {
        if debug { NSLog("[EzoicFlutterCmpSdk] Auto-present consent skipped: no foreground view controller") }
        return
      }
      EzoicCmp.presentConsentIfRequired(from: host) { outcome in
        if debug { NSLog("[EzoicFlutterCmpSdk] Auto-present consent outcome: \(consentOutcomeMap(outcome))") }
      }
    }
  }

  /// Presents the consent dialog (or the settings when `reopen`) from the
  /// top-most view controller. Always completes with an outcome map, never a
  /// `FlutterError`.
  private static func presentConsent(reopen: Bool, completion: @escaping ([String: Any]) -> Void) {
    DispatchQueue.main.async {
      guard let host = topViewController() else {
        completion(["type": "failed", "code": -1, "message": "No foreground view controller"])
        return
      }
      let deliver: (ConsentOutcome) -> Void = { completion(consentOutcomeMap($0)) }
      if reopen {
        EzoicCmp.presentConsentSettings(from: host, completion: deliver)
      } else {
        EzoicCmp.presentConsentIfRequired(from: host, completion: deliver)
      }
    }
  }

  /// The key window's root view controller (preferring foreground-active
  /// scenes), walked up to the top-most presented one that isn't being
  /// dismissed.
  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let active = scenes.filter { $0.activationState == .foregroundActive }
    let windows = (active.isEmpty ? scenes : active).flatMap { $0.windows }
    let window = windows.first { $0.isKeyWindow } ?? windows.first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController, !presented.isBeingDismissed {
      top = presented
    }
    return top
  }

  private static let unrecognizedOutcome: [String: Any] =
    ["type": "failed", "code": -1, "message": "Unrecognized outcome"]

  /// The outcome in the wire format the Dart `EzoicConsentOutcome.fromMap`
  /// parses. `.failed` carries the native error code, or -1 when it has none.
  static func consentOutcomeMap(_ outcome: ConsentOutcome) -> [String: Any] {
    switch outcome {
    case .notRequired:
      return ["type": "notRequired"]
    case .alreadyDecided:
      return ["type": "alreadyDecided"]
    case .decided(let decision):
      switch decision {
      case .acceptAll: return ["type": "decided", "decision": "acceptAll"]
      case .rejectAll: return ["type": "decided", "decision": "rejectAll"]
      case .custom: return ["type": "decided", "decision": "custom"]
      @unknown default: return unrecognizedOutcome
      }
    case .dismissed:
      return ["type": "dismissed"]
    case .alreadyPresenting:
      return ["type": "alreadyPresenting"]
    case .failed(let error):
      return ["type": "failed", "code": (error as? EzoicErrorCode)?.code ?? -1, "message": error.localizedDescription]
    @unknown default:
      return unrecognizedOutcome
    }
  }
}
