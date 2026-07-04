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

