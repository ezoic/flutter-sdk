# ezoic_flutter_sdk

A new Flutter plugin project.

## Getting Started

This project is a starting point for a Flutter
[plug-in package](https://flutter.dev/to/develop-plugins),
a specialized package that includes platform-specific implementation code for
Android and/or iOS.

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Native Ads

`EzoicNativeAdView` loads a native ad through the native SDKs and renders it in
an SDK-built template (a `NativeAdView` with the ad's headline, icon,
advertiser, media, body and call-to-action). It is a platform view, so it fills
its parent's constraints — wrap it in a `SizedBox` (or another constrained
parent) to size it:

```dart
import 'package:ezoic_flutter_sdk/ezoic_flutter_sdk.dart';

SizedBox(
  height: 320,
  child: EzoicNativeAdView(
    adUnitIdentifier: '12345',
    onLoad: () => debugPrint('native ad loaded'),
    onError: (error) => debugPrint('native ad failed: ${error.message}'),
    onImpression: () => debugPrint('native ad impression'),
    onClick: () => debugPrint('native ad clicked'),
    onOpen: () => debugPrint('native ad opened an overlay'),
    onClose: () => debugPrint('native ad overlay closed'),
  ),
)
```

The template and the underlying native ad are built and destroyed by the plugin
with the platform view's lifecycle — no manual `destroy()` call is required.

## Outstream Video

`EzoicOutstreamAdView` loads an outstream video ad through the native SDKs and
renders it inline through Google Ad Manager. Like the native ad view it is a
platform view, so it fills its parent's constraints — wrap it in a `SizedBox`
(or another constrained parent) to size it:

```dart
import 'package:ezoic_flutter_sdk/ezoic_flutter_sdk.dart';

SizedBox(
  height: 200,
  child: EzoicOutstreamAdView(
    adUnitIdentifier: '12345',
    onLoad: () => debugPrint('outstream ad loaded'),
    onError: (error) => debugPrint('outstream ad failed: ${error.message}'),
    onImpression: () => debugPrint('outstream ad impression'),
    onClick: () => debugPrint('outstream ad clicked'),
    onOpen: () => debugPrint('outstream ad opened an overlay'),
    onClose: () => debugPrint('outstream ad overlay closed'),
  ),
)
```

The video view and its underlying native ad are built and destroyed by the
plugin with the platform view's lifecycle — no manual `destroy()` call is
required.

## Instream Video

`EzoicInstreamAd` is a view-less controller for instream video. Instream video
runs inside your app's OWN video content: the host app owns the video player
and the Google IMA SDK. The controller renders nothing — its deliverable is a
GAM VAST ad-tag URL you feed to your IMA `AdsRequest`.

```dart
import 'package:ezoic_flutter_sdk/ezoic_flutter_sdk.dart';

final instream = EzoicInstreamAd('12345');

try {
  final tagUrl = await instream.load(contentUrl: playingVideoUrl);
  // Feed tagUrl to your IMA AdsRequest.adTagUrl and request the preroll.
} on EzoicInstreamAdError catch (e) {
  debugPrint('instream load failed: ${e.message}');
}

// When IMA reports an ad error, walk the floor waterfall to the next tag.
// A null result means the waterfall is exhausted — give up on the preroll.
final next = await instream.getNextAdTagUrl();

// When IMA reports the ad STARTED, fire the Ezoic impression pixel.
await instream.reportImpression();

// Instream is multi-use: the controller lives (and can prefetch the next tag)
// until you explicitly release it.
await instream.destroy();
```

Unlike the interstitial unit, `EzoicInstreamAd` is not single-use: keep the
controller and reuse it across loads, then call `destroy()` when done.

