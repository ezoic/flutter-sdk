import Flutter
import UIKit
import EzoicAdsSDKBinary

public class EzoicFlutterSdkPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.ezoic/ezoic_flutter_sdk", binaryMessenger: registrar.messenger())
    let instance = EzoicFlutterSdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    let factory = EzoicBannerViewFactory(messenger: registrar.messenger())
    registrar.register(factory, withId: "com.ezoic/ezoic_banner_view")
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      guard let args = call.arguments as? [String: Any],
            let domain = args["domain"] as? String, !domain.isEmpty else {
        result(FlutterError(code: "EzoicAds", message: "initialize requires a non-empty `domain`.", details: nil))
        return
      }
      let config = EzoicConfiguration(
        domain: domain,
        autoReadConsent: args["autoReadConsent"] as? Bool ?? true,
        subjectToCOPPA: args["subjectToCOPPA"] as? Bool ?? false,
        requestATTBeforeAds: args["requestATTBeforeAds"] as? Bool ?? true,
        debugEnabled: args["debugEnabled"] as? Bool ?? false,
        testMode: args["testMode"] as? Bool ?? false
      )
      EzoicAds.shared.initialize(with: config) { r in
        switch r {
        case .success: result(nil)
        case .failure(let e): result(FlutterError(code: "EzoicAds", message: e.localizedDescription, details: e.code))
        }
      }
    case "setGDPRConsent":
      let args = call.arguments as? [String: Any]
      EzoicAds.shared.setGDPRConsent(applies: args?["applies"] as? Bool ?? false,
                                     consentString: args?["consentString"] as? String)
      result(nil)
    case "setGPPConsent":
      let args = call.arguments as? [String: Any]
      EzoicAds.shared.setGPPConsent(gppString: args?["gppString"] as? String,
                                    sectionIds: args?["sectionIds"] as? String)
      result(nil)
    case "setSubjectToCOPPA":
      let args = call.arguments as? [String: Any]
      EzoicAds.shared.setSubjectToCOPPA(args?["value"] as? Bool ?? false)
      result(nil)
    case "trackPageview":
      EzoicAds.shared.trackPageview { success in result(success) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
