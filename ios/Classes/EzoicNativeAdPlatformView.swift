import Flutter
import UIKit
import EzoicAdsSDKBinary
import GoogleMobileAds

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
  private var adView: NativeAdView?
  private var loadStarted = false

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.ezoic/ezoic_native_ad_view_\(viewId)", binaryMessenger: messenger)
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
    EzoicNativeAd.load(adUnitIdentifier: adUnitId) { [weak self] result in
      guard let self = self else { return }
      switch result {
      case .success(let ad):
        self.ezoicNativeAd = ad
        guard let gmaAd = ad.nativeAd else {
          self.channel.invokeMethod(
            "onError", arguments: ["message": "Native ad loaded without content", "code": 0])
          return
        }
        // Attach the delegate before rendering so the impression, which fires
        // as soon as the NativeAdView is displayed, is delivered.
        ad.delegate = self
        self.render(gmaAd)
        self.channel.invokeMethod("onLoad", arguments: nil)
      case .failure(let error):
        self.channel.invokeMethod(
          "onError", arguments: ["message": error.localizedDescription, "code": error.code])
      }
    }
  }

  func view() -> UIView { container }

  /// Builds a template `NativeAdView` in code (mirrors the Android template):
  /// a header row (icon + headline/advertiser), a `MediaView`, the body text
  /// and a call-to-action button. The optional text/image assets are only
  /// created and registered when present, but the `MediaView` is always built:
  /// on GMA 12 `NativeAd.mediaContent` is non-optional and the media view is a
  /// required asset (unlike Android, where `mediaContent` is `@Nullable`).
  /// `adView.nativeAd` is assigned last.
  private func render(_ gmaAd: GoogleMobileAds.NativeAd) {
    let adView = NativeAdView()
    adView.translatesAutoresizingMaskIntoConstraints = false

    let mainStack = UIStackView()
    mainStack.axis = .vertical
    mainStack.spacing = 8
    mainStack.translatesAutoresizingMaskIntoConstraints = false

    let headerRow = UIStackView()
    headerRow.axis = .horizontal
    headerRow.spacing = 8
    headerRow.alignment = .center

    if let image = gmaAd.icon?.image {
      let iconView = UIImageView(image: image)
      iconView.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        iconView.widthAnchor.constraint(equalToConstant: 40),
        iconView.heightAnchor.constraint(equalToConstant: 40),
      ])
      headerRow.addArrangedSubview(iconView)
      adView.iconView = iconView
    }

    let textColumn = UIStackView()
    textColumn.axis = .vertical

    if let headline = gmaAd.headline {
      let label = UILabel()
      label.text = headline
      label.font = .boldSystemFont(ofSize: 16)
      label.numberOfLines = 0
      textColumn.addArrangedSubview(label)
      adView.headlineView = label
    }

    if let advertiser = gmaAd.advertiser {
      let label = UILabel()
      label.text = advertiser
      label.font = .systemFont(ofSize: 12)
      textColumn.addArrangedSubview(label)
      adView.advertiserView = label
    }

    headerRow.addArrangedSubview(textColumn)
    mainStack.addArrangedSubview(headerRow)

    let mediaView = MediaView()
    mediaView.mediaContent = gmaAd.mediaContent
    mediaView.translatesAutoresizingMaskIntoConstraints = false
    // Priority 999 so a caller-supplied SizedBox shorter than the template's
    // natural height breaks this constraint instead of spamming
    // unsatisfiable-constraint logs (Android clips silently in that case).
    let mediaHeight = mediaView.heightAnchor.constraint(equalToConstant: 175)
    mediaHeight.priority = UILayoutPriority(999)
    mediaHeight.isActive = true
    mainStack.addArrangedSubview(mediaView)
    adView.mediaView = mediaView

    if let body = gmaAd.body {
      let label = UILabel()
      label.text = body
      label.font = .systemFont(ofSize: 14)
      label.numberOfLines = 0
      mainStack.addArrangedSubview(label)
      adView.bodyView = label
    }

    if let cta = gmaAd.callToAction {
      let button = UIButton(type: .system)
      button.setTitle(cta, for: .normal)
      // The NativeAdView handles the tap; the button must not intercept it.
      button.isUserInteractionEnabled = false
      mainStack.addArrangedSubview(button)
      adView.callToActionView = button
    }

    adView.addSubview(mainStack)
    NSLayoutConstraint.activate([
      mainStack.topAnchor.constraint(equalTo: adView.topAnchor, constant: 8),
      mainStack.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 8),
      mainStack.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -8),
      mainStack.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -8),
    ])

    container.addSubview(adView)
    NSLayoutConstraint.activate([
      adView.topAnchor.constraint(equalTo: container.topAnchor),
      adView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      adView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      adView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])

    adView.nativeAd = gmaAd
    self.adView = adView
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
