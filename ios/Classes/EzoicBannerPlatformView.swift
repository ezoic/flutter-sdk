import Flutter
import UIKit
import EzoicAdsSDKBinary

class EzoicBannerViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    return EzoicBannerPlatformView(frame: frame, viewId: viewId, args: args, messenger: messenger)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
}

class EzoicBannerPlatformView: NSObject, FlutterPlatformView, EzoicBannerViewDelegate {
  private let container = UIView()
  private let channel: FlutterMethodChannel
  private var banner: EzoicBannerView?

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.ezoic/ezoic_banner_view_\(viewId)", binaryMessenger: messenger)
    super.init()
    let params = args as? [String: Any]
    let adUnitId = Int(params?["adUnitIdentifier"] as? String ?? "") ?? 0
    let sizes = (params?["size"] as? String ?? "").split(separator: ",").map { String($0) }
    let view = EzoicBannerView(adUnitIdentifier: adUnitId)
    view.delegate = self
    view.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(view)
    NSLayoutConstraint.activate([
      view.centerXAnchor.constraint(equalTo: container.centerXAnchor),
      view.centerYAnchor.constraint(equalTo: container.centerYAnchor),
    ])
    banner = view
    if sizes.isEmpty { view.loadAd() } else { view.loadAd(sizes: sizes) }
  }

  func view() -> UIView { container }

  func bannerViewDidLoad(_ bannerView: EzoicBannerView) { channel.invokeMethod("onLoad", arguments: nil) }
  func bannerView(_ bannerView: EzoicBannerView, didFailToLoadWithError error: EzoicError) {
    channel.invokeMethod("onError", arguments: ["message": error.localizedDescription, "code": error.code])
  }
  func bannerViewDidRecordImpression(_ bannerView: EzoicBannerView) { channel.invokeMethod("onImpression", arguments: nil) }
  func bannerViewDidRecordClick(_ bannerView: EzoicBannerView) { channel.invokeMethod("onClick", arguments: nil) }
  func bannerViewWillPresentScreen(_ bannerView: EzoicBannerView) { channel.invokeMethod("onOpen", arguments: nil) }
  func bannerViewDidDismissScreen(_ bannerView: EzoicBannerView) { channel.invokeMethod("onClose", arguments: nil) }
}
