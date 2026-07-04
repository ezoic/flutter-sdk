import Flutter
import UIKit
import EzoicAdsSDKBinary

class EzoicOutstreamAdViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    return EzoicOutstreamAdPlatformView(frame: frame, viewId: viewId, args: args, messenger: messenger)
  }

  // Required or creationParams arrive nil on the native side.
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
}

class EzoicOutstreamAdPlatformView: NSObject, FlutterPlatformView, EzoicOutstreamAdViewDelegate {
  private let container = UIView()
  private let channel: FlutterMethodChannel
  private let adUnitId: Int
  // The delegate is weak on the SDK side; this platform view retains the ad
  // view AND conforms to the delegate, so the ad view keeps a live delegate.
  private var outstreamView: EzoicOutstreamAdView?
  private var loadStarted = false

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.ezoic/ezoic_outstream_ad_view_\(viewId)", binaryMessenger: messenger)
    let params = args as? [String: Any]
    adUnitId = Int(params?["adUnitIdentifier"] as? String ?? "") ?? 0
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
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func startLoad() {
    // A second "load" is a no-op success; the guard survives across calls.
    if loadStarted { return }
    loadStarted = true

    // Unlike the native-ad unit there is no separate ad object — the VIEW is
    // the ad. Add it before loading so it renders in place when filled.
    let view = EzoicOutstreamAdView(adUnitIdentifier: adUnitId)
    outstreamView = view
    // Assign the delegate BEFORE loadAd(): native loadAd() fails synchronously
    // when the SDK is uninitialized, so onError must already be wired.
    view.delegate = self
    container.addSubview(view)
    view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: container.topAnchor),
      view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
    view.loadAd()
  }

  func view() -> UIView { container }

  // MARK: - EzoicOutstreamAdViewDelegate

  func outstreamViewDidLoad(_ outstreamView: EzoicOutstreamAdView) {
    channel.invokeMethod("onLoad", arguments: nil)
  }

  func outstreamView(_ outstreamView: EzoicOutstreamAdView, didFailToLoadWithError error: EzoicError) {
    channel.invokeMethod("onError", arguments: ["message": error.localizedDescription, "code": error.code])
  }

  func outstreamViewDidRecordImpression(_ outstreamView: EzoicOutstreamAdView) {
    channel.invokeMethod("onImpression", arguments: nil)
  }

  func outstreamViewDidRecordClick(_ outstreamView: EzoicOutstreamAdView) {
    channel.invokeMethod("onClick", arguments: nil)
  }

  func outstreamViewWillPresentScreen(_ outstreamView: EzoicOutstreamAdView) {
    channel.invokeMethod("onOpen", arguments: nil)
  }

  func outstreamViewDidDismissScreen(_ outstreamView: EzoicOutstreamAdView) {
    channel.invokeMethod("onClose", arguments: nil)
  }

  deinit {
    // Release the handler block the messenger holds per channel name; the
    // [weak self] capture keeps the view collectable either way.
    channel.setMethodCallHandler(nil)
    outstreamView?.destroy()
  }
}
