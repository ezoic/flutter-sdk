import Flutter
import UIKit
import EzoicAdsSDKBinary

public class EzoicFlutterSdkPlugin: NSObject, FlutterPlugin {
  private var messenger: FlutterBinaryMessenger?

  /// Loaded rewarded ads awaiting `show`, keyed by ad unit id.
  private var rewardedAds: [Int: EzoicRewardedAd] = [:]

  /// Per-ad event channels used to surface lifecycle callbacks to Dart.
  private var rewardedChannels: [Int: FlutterMethodChannel] = [:]

  /// In-flight `show` calls, keyed by ad unit id.
  private var pendingShows: [Int: PendingRewardShow] = [:]

  private final class PendingRewardShow {
    let result: FlutterResult
    var reward: EzoicReward?
    var settled = false
    init(_ result: @escaping FlutterResult) { self.result = result }
  }

  /// Loaded interstitial ads awaiting `show`, keyed by ad unit id.
  private var interstitialAds: [Int: EzoicInterstitialAd] = [:]

  /// Per-ad event channels used to surface interstitial callbacks to Dart.
  private var interstitialChannels: [Int: FlutterMethodChannel] = [:]

  /// In-flight interstitial `show` calls, keyed by ad unit id.
  private var pendingInterstitialShows: [Int: PendingInterstitialShow] = [:]

  private final class PendingInterstitialShow {
    let result: FlutterResult
    var settled = false
    init(_ result: @escaping FlutterResult) { self.result = result }
  }

  /// Ad unit ids with an in-flight rewarded `load`.
  private var loadingRewarded: Set<Int> = []

  /// Ad unit ids with an in-flight interstitial `load`.
  private var loadingInterstitial: Set<Int> = []

  /// Live instream controllers, keyed by ad unit id. The plugin RETAINS these
  /// because the SDK delegate is weak and the plugin object is the delegate;
  /// instream is multi-use, so a repeat load reuses the existing controller.
  private var instreamAds: [Int: EzoicInstreamAd] = [:]

  /// In-flight instream `load` calls, keyed by ad unit id. Doubles as the
  /// overlapping-load guard (the native load silently no-ops while loading,
  /// which would otherwise hang the Dart future).
  private var pendingInstreamLoads: [Int: PendingInstreamLoad] = [:]

  private final class PendingInstreamLoad {
    let result: FlutterResult
    var settled = false
    init(_ result: @escaping FlutterResult) { self.result = result }
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.ezoic/ezoic_flutter_sdk", binaryMessenger: registrar.messenger())
    let instance = EzoicFlutterSdkPlugin()
    instance.messenger = registrar.messenger()
    registrar.addMethodCallDelegate(instance, channel: channel)

    let factory = EzoicBannerViewFactory(messenger: registrar.messenger())
    registrar.register(factory, withId: "com.ezoic/ezoic_banner_view")

    let nativeFactory = EzoicNativeAdViewFactory(messenger: registrar.messenger())
    registrar.register(nativeFactory, withId: "com.ezoic/ezoic_native_ad_view")

    let outstreamFactory = EzoicOutstreamAdViewFactory(messenger: registrar.messenger())
    registrar.register(outstreamFactory, withId: "com.ezoic/ezoic_outstream_ad_view")
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
        testMode: args["testMode"] as? Bool ?? false,
        autoTrackPageviews: args["autoTrackPageviews"] as? Bool ?? true,
        cmpEnabled: args["cmpEnabled"] as? Bool ?? true
      )
      let autoPresentConsent = args["autoPresentConsent"] as? Bool ?? true
      EzoicAds.shared.initialize(with: config) { r in
        switch r {
        case .success:
          result(nil)
          if autoPresentConsent { Self.autoPresentConsent(debug: config.debugEnabled) }
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
      let args = call.arguments as? [String: Any]
      if let screen = args?["screen"] as? String, !screen.isEmpty {
        EzoicAds.shared.trackPageview(screen: screen) { success in result(success) }
      } else {
        EzoicAds.shared.trackPageview { success in result(success) }
      }
    case "presentConsentIfRequired":
      presentConsent(reopen: false) { result($0) }
    case "presentConsentSettings":
      presentConsent(reopen: true) { result($0) }
    case "isConsentRequired":
      result(EzoicAds.shared.isConsentRequired)
    case "resetConsent":
      EzoicAds.shared.resetConsent()
      result(nil)
    case "loadRewardedAd":
      handleLoadRewardedAd(call, result)
    case "showRewardedAd":
      handleShowRewardedAd(call, result)
    case "loadInterstitialAd":
      handleLoadInterstitialAd(call, result)
    case "showInterstitialAd":
      handleShowInterstitialAd(call, result)
    case "loadInstreamAd":
      handleLoadInstreamAd(call, result)
    case "getInstreamNextAdTagUrl":
      handleGetInstreamNextAdTagUrl(call, result)
    case "reportInstreamImpression":
      handleReportInstreamImpression(call, result)
    case "destroyInstreamAd":
      handleDestroyInstreamAd(call, result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Runs once after a successful `initialize` when `autoPresentConsent` is on.
  /// The outcome is only logged; apps that need it call `presentConsentIfRequired`.
  private static func autoPresentConsent(debug: Bool) {
    DispatchQueue.main.async {
      guard let host = Self.topViewController() else {
        if debug { NSLog("[EzoicFlutterSdk] Auto-present consent skipped: no foreground view controller") }
        return
      }
      EzoicAds.shared.presentConsentIfRequired(from: host) { outcome in
        if debug { NSLog("[EzoicFlutterSdk] Auto-present consent outcome: \(Self.consentOutcomeMap(outcome))") }
      }
    }
  }

  /// Presents the consent dialog (or its settings view when `reopen`) from the
  /// top-most view controller and delivers the outcome in the wire format
  /// shared with the Dart side. Always completes with an outcome map, never a
  /// `FlutterError`.
  private func presentConsent(reopen: Bool, completion: @escaping ([String: Any]) -> Void) {
    DispatchQueue.main.async {
      guard let host = Self.topViewController() else {
        completion(["type": "failed", "code": -1, "message": "No foreground view controller"])
        return
      }
      let deliver: (ConsentOutcome) -> Void = { completion(Self.consentOutcomeMap($0)) }
      if reopen {
        EzoicAds.shared.presentConsentSettings(from: host, completion: deliver)
      } else {
        EzoicAds.shared.presentConsentIfRequired(from: host, completion: deliver)
      }
    }
  }

  /// The key window's root view controller, walked up to the top-most
  /// presented one.
  private static func topViewController() -> UIViewController? {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
    let window = windows.first { $0.isKeyWindow } ?? windows.first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }

  private static func consentOutcomeMap(_ outcome: ConsentOutcome) -> [String: Any] {
    switch outcome {
    case .notRequired:
      return ["type": "notRequired"]
    case .alreadyDecided:
      return ["type": "alreadyDecided"]
    case .decided(let decision):
      let name: String
      switch decision {
      case .acceptAll: name = "acceptAll"
      case .rejectAll: name = "rejectAll"
      case .custom: name = "custom"
      @unknown default: name = "unknown"
      }
      return ["type": "decided", "decision": name]
    case .dismissed:
      return ["type": "dismissed"]
    case .alreadyPresenting:
      return ["type": "alreadyPresenting"]
    case .failed(let error):
      return ["type": "failed", "code": error.code, "message": error.localizedDescription]
    @unknown default:
      return ["type": "failed", "code": -1, "message": "Unrecognized outcome"]
    }
  }

  private func handleLoadRewardedAd(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let adUnitIdentifier = args["adUnitIdentifier"] as? String,
          let id = Int(adUnitIdentifier) else {
      result(FlutterError(code: "EzoicAds", message: "Invalid adUnitIdentifier.", details: nil))
      return
    }
    if rewardedAds[id] != nil || loadingRewarded.contains(id) {
      result(FlutterError(code: "EzoicAds",
                          message: "An ad is already loaded/loading for ad unit \(adUnitIdentifier)",
                          details: nil))
      return
    }
    loadingRewarded.insert(id)
    EzoicRewardedAd.load(adUnitIdentifier: id) { [weak self] r in
      guard let self = self else { return }
      self.loadingRewarded.remove(id)
      switch r {
      case .success(let ad):
        ad.delegate = self
        self.rewardedAds[id] = ad
        if let messenger = self.messenger, self.rewardedChannels[id] == nil {
          self.rewardedChannels[id] = FlutterMethodChannel(
            name: "com.ezoic/ezoic_rewarded_ad_\(id)", binaryMessenger: messenger)
        }
        result(nil)
      case .failure(let e):
        result(FlutterError(code: "EzoicAds", message: e.localizedDescription, details: e.code))
      }
    }
  }

  private func handleShowRewardedAd(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let adUnitIdentifier = args["adUnitIdentifier"] as? String,
          let id = Int(adUnitIdentifier), let ad = rewardedAds[id] else {
      result(FlutterError(code: "EzoicAds", message: "Rewarded ad not loaded.", details: nil))
      return
    }
    if pendingShows[id] != nil {
      result(FlutterError(code: "EzoicAds",
                          message: "A show is already in progress for ad unit \(adUnitIdentifier)",
                          details: nil))
      return
    }
    pendingShows[id] = PendingRewardShow(result)
    let rewardName = args["rewardName"] as? String
    // Presenting from nil lets GMA use the application's top view controller.
    ad.show(from: nil, rewardName: rewardName) { [weak self] reward in
      self?.pendingShows[id]?.reward = reward
    }
  }

  private func emit(_ id: Int, _ method: String, _ args: Any? = nil) {
    rewardedChannels[id]?.invokeMethod(method, arguments: args)
  }

  private func handleLoadInterstitialAd(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let adUnitIdentifier = args["adUnitIdentifier"] as? String,
          let id = Int(adUnitIdentifier) else {
      result(FlutterError(code: "EzoicAds", message: "Invalid adUnitIdentifier.", details: nil))
      return
    }
    if interstitialAds[id] != nil || loadingInterstitial.contains(id) {
      result(FlutterError(code: "EzoicAds",
                          message: "An ad is already loaded/loading for ad unit \(adUnitIdentifier)",
                          details: nil))
      return
    }
    loadingInterstitial.insert(id)
    EzoicInterstitialAd.load(adUnitIdentifier: id) { [weak self] r in
      guard let self = self else { return }
      self.loadingInterstitial.remove(id)
      switch r {
      case .success(let ad):
        ad.delegate = self
        self.interstitialAds[id] = ad
        if let messenger = self.messenger, self.interstitialChannels[id] == nil {
          self.interstitialChannels[id] = FlutterMethodChannel(
            name: "com.ezoic/ezoic_interstitial_ad_\(id)", binaryMessenger: messenger)
        }
        result(nil)
      case .failure(let e):
        result(FlutterError(code: "EzoicAds", message: e.localizedDescription, details: e.code))
      }
    }
  }

  private func handleShowInterstitialAd(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let adUnitIdentifier = args["adUnitIdentifier"] as? String,
          let id = Int(adUnitIdentifier), let ad = interstitialAds[id] else {
      result(FlutterError(code: "EzoicAds", message: "Interstitial ad not loaded.", details: nil))
      return
    }
    if pendingInterstitialShows[id] != nil {
      result(FlutterError(code: "EzoicAds",
                          message: "A show is already in progress for ad unit \(adUnitIdentifier)",
                          details: nil))
      return
    }
    pendingInterstitialShows[id] = PendingInterstitialShow(result)
    // Native show(from:) has no completion handler, so the show promise is
    // settled from the delegate (dismiss = resolve, failed-to-present = reject).
    // Presenting from nil lets GMA use the application's top view controller.
    ad.show(from: nil)
  }

  private func emitInterstitial(_ id: Int, _ method: String, _ args: Any? = nil) {
    interstitialChannels[id]?.invokeMethod(method, arguments: args)
  }

  private func handleLoadInstreamAd(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let adUnitIdentifier = args["adUnitIdentifier"] as? String,
          let id = Int(adUnitIdentifier) else {
      result(FlutterError(code: "EzoicAds", message: "Invalid adUnitIdentifier.", details: nil))
      return
    }
    // Reject overlapping loads for this ad unit: the native load silently
    // no-ops while loading, which would hang the Dart future.
    if pendingInstreamLoads[id] != nil {
      result(FlutterError(code: "EzoicAds",
                          message: "An instream ad is already loading for ad unit \(adUnitIdentifier)",
                          details: nil))
      return
    }
    let contentUrl = args["contentUrl"] as? String

    // Create-or-reuse: instream is multi-use, so a repeat load on the same id
    // reuses the existing native controller (preserving its tag state).
    let ad: EzoicInstreamAd
    if let existing = instreamAds[id] {
      ad = existing
    } else {
      ad = EzoicInstreamAd(adUnitId: id)
      instreamAds[id] = ad
    }

    // Register the pending holder BEFORE calling load: early validation
    // failures deliver the delegate callback synchronously.
    pendingInstreamLoads[id] = PendingInstreamLoad(result)
    ad.load(contentUrl: contentUrl, delegate: self)
  }

  private func handleGetInstreamNextAdTagUrl(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let adUnitIdentifier = args["adUnitIdentifier"] as? String,
          let id = Int(adUnitIdentifier) else {
      result(FlutterError(code: "EzoicAds", message: "Invalid adUnitIdentifier.", details: nil))
      return
    }
    result(instreamAds[id]?.getNextAdTagUrl())
  }

  private func handleReportInstreamImpression(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let adUnitIdentifier = args["adUnitIdentifier"] as? String,
          let id = Int(adUnitIdentifier) else {
      result(FlutterError(code: "EzoicAds", message: "Invalid adUnitIdentifier.", details: nil))
      return
    }
    // revenueUsd may arrive as an integer NSNumber over the codec when whole;
    // unwrap via NSNumber and pass the SDK's optional Double.
    let revenueUsd = (args["revenueUsd"] as? NSNumber)?.doubleValue
    instreamAds[id]?.reportImpression(revenueUsd: revenueUsd)
    result(nil)
  }

  private func handleDestroyInstreamAd(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let adUnitIdentifier = args["adUnitIdentifier"] as? String,
          let id = Int(adUnitIdentifier) else {
      result(FlutterError(code: "EzoicAds", message: "Invalid adUnitIdentifier.", details: nil))
      return
    }
    // The native SDKs ignore load callbacks once an ad is destroyed, so a
    // pending load's Flutter result must be settled here or it hangs forever.
    if let pending = pendingInstreamLoads.removeValue(forKey: id), !pending.settled {
      pending.settled = true
      pending.result(FlutterError(code: "EzoicAds", message: "Instream ad was destroyed while loading", details: nil))
    }
    instreamAds.removeValue(forKey: id)?.destroy()
    result(nil)
  }
}

// MARK: - EzoicRewardedAdDelegate

extension EzoicFlutterSdkPlugin: EzoicRewardedAdDelegate {

  public func rewardedAdDidPresent(_ rewardedAd: EzoicRewardedAd) {
    emit(rewardedAd.adUnitIdentifier, "onShown")
  }

  public func rewardedAd(_ rewardedAd: EzoicRewardedAd, didFailToPresentWithError error: EzoicError) {
    let id = rewardedAd.adUnitIdentifier
    emit(id, "onFailedToShow", ["message": error.localizedDescription, "code": error.code])
    rewardedAds.removeValue(forKey: id)
    if let pending = pendingShows.removeValue(forKey: id), !pending.settled {
      pending.settled = true
      pending.result(FlutterError(code: "EzoicAds", message: error.localizedDescription, details: error.code))
    }
  }

  public func rewardedAdDidRecordImpression(_ rewardedAd: EzoicRewardedAd) {
    emit(rewardedAd.adUnitIdentifier, "onImpression")
  }

  public func rewardedAdDidRecordClick(_ rewardedAd: EzoicRewardedAd) {
    emit(rewardedAd.adUnitIdentifier, "onClicked")
  }

  public func rewardedAd(_ rewardedAd: EzoicRewardedAd, userDidEarn reward: EzoicReward) {
    emit(rewardedAd.adUnitIdentifier, "onUserEarnedReward", ["type": reward.type, "amount": reward.amount])
    pendingShows[rewardedAd.adUnitIdentifier]?.reward = reward
  }

  public func rewardedAdDidDismiss(_ rewardedAd: EzoicRewardedAd) {
    let id = rewardedAd.adUnitIdentifier
    emit(id, "onDismissed")
    let pending = pendingShows.removeValue(forKey: id)
    rewardedAds.removeValue(forKey: id)
    if let pending = pending, !pending.settled {
      pending.settled = true
      let reward = pending.reward
      pending.result([
        "earned": reward != nil,
        "type": reward?.type ?? "",
        "amount": reward?.amount ?? 0
      ])
    }
  }
}

// MARK: - EzoicInterstitialAdDelegate

extension EzoicFlutterSdkPlugin: EzoicInterstitialAdDelegate {

  public func interstitialAdDidPresent(_ interstitialAd: EzoicInterstitialAd) {
    emitInterstitial(interstitialAd.adUnitIdentifier, "onShown")
  }

  public func interstitialAd(_ interstitialAd: EzoicInterstitialAd, didFailToPresentWithError error: EzoicError) {
    let id = interstitialAd.adUnitIdentifier
    emitInterstitial(id, "onFailedToShow", ["message": error.localizedDescription, "code": error.code])
    interstitialAds.removeValue(forKey: id)
    if let pending = pendingInterstitialShows.removeValue(forKey: id), !pending.settled {
      pending.settled = true
      pending.result(FlutterError(code: "EzoicAds", message: error.localizedDescription, details: error.code))
    }
  }

  public func interstitialAdDidRecordImpression(_ interstitialAd: EzoicInterstitialAd) {
    emitInterstitial(interstitialAd.adUnitIdentifier, "onImpression")
  }

  public func interstitialAdDidRecordClick(_ interstitialAd: EzoicInterstitialAd) {
    emitInterstitial(interstitialAd.adUnitIdentifier, "onClicked")
  }

  public func interstitialAdDidDismiss(_ interstitialAd: EzoicInterstitialAd) {
    let id = interstitialAd.adUnitIdentifier
    emitInterstitial(id, "onDismissed")
    let pending = pendingInterstitialShows.removeValue(forKey: id)
    interstitialAds.removeValue(forKey: id)
    if let pending = pending, !pending.settled {
      pending.settled = true
      pending.result(nil)
    }
  }
}

// MARK: - EzoicInstreamAdDelegate

extension EzoicFlutterSdkPlugin: EzoicInstreamAdDelegate {

  public func instreamAd(_ instreamAd: EzoicInstreamAd, didReceiveAdTag adTagUrl: String) {
    let id = instreamAd.adUnitId
    if let pending = pendingInstreamLoads.removeValue(forKey: id), !pending.settled {
      pending.settled = true
      pending.result(adTagUrl)
    }
  }

  public func instreamAd(_ instreamAd: EzoicInstreamAd, didFailToLoadWithError error: EzoicError) {
    let id = instreamAd.adUnitId
    if let pending = pendingInstreamLoads.removeValue(forKey: id), !pending.settled {
      pending.settled = true
      pending.result(FlutterError(code: "EzoicAds", message: error.localizedDescription, details: error.code))
    }
  }
}
