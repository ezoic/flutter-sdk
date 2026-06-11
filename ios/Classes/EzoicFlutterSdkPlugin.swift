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

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.ezoic/ezoic_flutter_sdk", binaryMessenger: registrar.messenger())
    let instance = EzoicFlutterSdkPlugin()
    instance.messenger = registrar.messenger()
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
    case "loadRewardedAd":
      handleLoadRewardedAd(call, result)
    case "showRewardedAd":
      handleShowRewardedAd(call, result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleLoadRewardedAd(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let adUnitIdentifier = args["adUnitIdentifier"] as? String,
          let id = Int(adUnitIdentifier) else {
      result(FlutterError(code: "EzoicAds", message: "Invalid adUnitIdentifier.", details: nil))
      return
    }
    EzoicRewardedAd.load(adUnitIdentifier: id) { [weak self] r in
      guard let self = self else { return }
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
    pendingShows[id] = PendingRewardShow(result)
    // Presenting from nil lets GMA use the application's top view controller.
    ad.show(from: nil) { [weak self] reward in
      self?.pendingShows[id]?.reward = reward
    }
  }

  private func emit(_ id: Int, _ method: String, _ args: Any? = nil) {
    rewardedChannels[id]?.invokeMethod(method, arguments: args)
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
