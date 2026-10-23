import Flutter
import UIKit
import EzoicAdsSDKBinary

class EzoicNativeAdViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    return EzoicNativeAdPlatformView(frame: frame, viewId: viewId, args: args, messenger: messenger)
  }

  // Required or creationParams arrive nil on the native side.
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
}

class EzoicNativeAdPlatformView: NSObject, FlutterPlatformView, EzoicNativeAdDelegate {
  private let container = UIView()
  private let channel: FlutterMethodChannel
  private let adUnitId: Int
  private var ezoicNativeAd: EzoicNativeAd?
  private var templateView: EzoicNativeAdTemplateView?
  private var adStyle: EzoicNativeAdStyle
  private var loadStarted = false

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.ezoic/ezoic_native_ad_view_\(viewId)", binaryMessenger: messenger)
    let params = args as? [String: Any]
    adUnitId = Int(params?["adUnitIdentifier"] as? String ?? "") ?? 0
    adStyle = EzoicNativeAdStyle(dictionary: params?["adStyle"] as? [String: Any])
    super.init()
    // The load is triggered by an explicit "load" call from Dart rather than
    // here, so the Dart-side handler is attached before the native SDK can
    // fail synchronously (e.g. not initialized) and drop onError.
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      switch call.method {
      case "load":
        self.startLoad()
        result(nil)
      case "setStyle":
        self.adStyle = EzoicNativeAdStyle(dictionary: call.arguments as? [String: Any])
        self.templateView?.style = self.adStyle
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func startLoad() {
    // A second "load" is a no-op success; the guard survives across calls.
    if loadStarted { return }
    loadStarted = true
    EzoicNativeAd.load(adUnitIdentifier: adUnitId) { [weak self] result in
      guard let self = self else { return }
      switch result {
      case .success(let ad):
        self.ezoicNativeAd = ad
        guard ad.nativeAd != nil else {
          self.channel.invokeMethod(
            "onError", arguments: ["message": "Native ad loaded without content", "code": 0])
          return
        }
        // Attach the delegate before rendering so the impression, which fires
        // as soon as the NativeAdView is displayed, is delivered.
        ad.delegate = self
        self.render(ad)
        self.channel.invokeMethod("onLoad", arguments: nil)
      case .failure(let error):
        self.channel.invokeMethod(
          "onError", arguments: ["message": error.localizedDescription, "code": error.code])
      }
    }
  }

  func view() -> UIView { container }

  /// Shows the ad in the SDK template, which also registers it for viewability.
  private func render(_ ad: EzoicNativeAd) {
    templateView?.removeFromSuperview()
    let view = EzoicNativeAdTemplateView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.style = adStyle
    container.addSubview(view)
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: container.topAnchor),
      view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
    view.nativeAd = ad
    templateView = view
  }

  // MARK: - EzoicNativeAdDelegate

  func nativeAdDidRecordImpression(_ nativeAd: EzoicNativeAd) {
    channel.invokeMethod("onImpression", arguments: nil)
  }

  func nativeAdDidRecordClick(_ nativeAd: EzoicNativeAd) {
    channel.invokeMethod("onClick", arguments: nil)
  }

  func nativeAdWillPresentScreen(_ nativeAd: EzoicNativeAd) {
    channel.invokeMethod("onOpen", arguments: nil)
  }

  func nativeAdDidDismissScreen(_ nativeAd: EzoicNativeAd) {
    channel.invokeMethod("onClose", arguments: nil)
  }

  deinit {
    // Release the handler block the messenger holds per channel name; the
    // [weak self] capture keeps the view collectable either way.
    channel.setMethodCallHandler(nil)
    ezoicNativeAd?.destroy()
  }
}
