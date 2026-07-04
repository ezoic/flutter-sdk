import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Error delivered to [EzoicNativeAdView.onError] when a native ad fails to
/// load.
class EzoicNativeAdError {
  final String message;
  final int code;
  const EzoicNativeAdError(this.message, this.code);
}

/// Builds the per-view method-call handler that routes native ad lifecycle
/// events from the platform channel to the supplied callbacks.
///
/// Factored out of [EzoicNativeAdView] so the dispatch logic can be exercised
/// in unit tests without instantiating a platform view (platform-view creation
/// is not available in plain widget tests). Unknown methods are ignored.
@visibleForTesting
Future<dynamic> Function(MethodCall call) createEzoicNativeAdMethodCallHandler({
  VoidCallback? onLoad,
  void Function(EzoicNativeAdError error)? onError,
  VoidCallback? onImpression,
  VoidCallback? onClick,
  VoidCallback? onOpen,
  VoidCallback? onClose,
}) {
  return (MethodCall call) async {
    switch (call.method) {
      case 'onLoad':
        onLoad?.call();
        break;
      case 'onError':
        final args =
            (call.arguments as Map?)?.cast<String, dynamic>() ?? const {};
        onError?.call(EzoicNativeAdError(
          args['message'] as String? ?? 'Unknown error',
          (args['code'] as num?)?.toInt() ?? 0,
        ));
        break;
      case 'onImpression':
        onImpression?.call();
        break;
      case 'onClick':
        onClick?.call();
        break;
      case 'onOpen':
        onOpen?.call();
        break;
      case 'onClose':
        onClose?.call();
        break;
    }
  };
}

/// Attaches the per-view method-call handler to [channel] and then triggers the
/// native ad load.
///
/// The load handshake matters: both native SDKs can fail synchronously inside
/// their load call (e.g. the SDK is not initialized), so the load must not
/// start until the handler is attached — otherwise the `onError` invocation
/// fires before Dart is listening and is silently dropped. The outgoing `load`
/// future is intentionally unawaited and its errors are swallowed so a
/// platform-side failure never surfaces as an unhandled rejection; the failure
/// is instead delivered through the `onError` handler.
///
/// Factored out of [EzoicNativeAdView] so the attach-then-load seam can be
/// exercised in unit tests without instantiating a platform view.
@visibleForTesting
void attachEzoicNativeAdChannel(
  MethodChannel channel, {
  VoidCallback? onLoad,
  void Function(EzoicNativeAdError error)? onError,
  VoidCallback? onImpression,
  VoidCallback? onClick,
  VoidCallback? onOpen,
  VoidCallback? onClose,
}) {
  channel.setMethodCallHandler(createEzoicNativeAdMethodCallHandler(
    onLoad: onLoad,
    onError: onError,
    onImpression: onImpression,
    onClick: onClick,
    onOpen: onOpen,
    onClose: onClose,
  ));
  unawaited(channel.invokeMethod<void>('load').catchError((_) {}));
}

/// An Ezoic native ad, embedded via a platform view.
///
/// The native SDK loads a native ad and renders it in an SDK-built template
/// `NativeAdView` (Android `com.google.android.gms.ads.nativead.NativeAdView`,
/// iOS Google Mobile Ads `NativeAdView`), forwarding the lifecycle callbacks to
/// the supplied handlers.
///
/// Platform views fill their parent's constraints, so size the ad by wrapping
/// it in a [SizedBox] (or another constrained parent):
///
/// ```dart
/// SizedBox(
///   height: 320,
///   child: EzoicNativeAdView(
///     adUnitIdentifier: '12345',
///     onLoad: () => debugPrint('native loaded'),
///   ),
/// )
/// ```
class EzoicNativeAdView extends StatefulWidget {
  /// The Ezoic ad unit identifier. Crosses the bridge as a string and is
  /// coerced to a native `Int`.
  final String adUnitIdentifier;

  /// Called when the native ad successfully loads.
  final VoidCallback? onLoad;

  /// Called when the native ad fails to load.
  final void Function(EzoicNativeAdError error)? onError;

  /// Called when the native ad records an impression.
  final VoidCallback? onImpression;

  /// Called when the native ad is clicked.
  final VoidCallback? onClick;

  /// Called when a click on the native ad presents a full-screen overlay.
  final VoidCallback? onOpen;

  /// Called when a presented full-screen overlay is dismissed.
  final VoidCallback? onClose;

  const EzoicNativeAdView({
    super.key,
    required this.adUnitIdentifier,
    this.onLoad,
    this.onError,
    this.onImpression,
    this.onClick,
    this.onOpen,
    this.onClose,
  });

  @override
  State<EzoicNativeAdView> createState() => _EzoicNativeAdViewState();
}

class _EzoicNativeAdViewState extends State<EzoicNativeAdView> {
  static const String _viewType = 'com.ezoic/ezoic_native_ad_view';

  Map<String, dynamic> get _creationParams => {
        'adUnitIdentifier': widget.adUnitIdentifier,
      };

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('com.ezoic/ezoic_native_ad_view_$id');
    attachEzoicNativeAdChannel(
      channel,
      onLoad: () => widget.onLoad?.call(),
      onError: (error) => widget.onError?.call(error),
      onImpression: () => widget.onImpression?.call(),
      onClick: () => widget.onClick?.call(),
      onOpen: () => widget.onOpen?.call(),
      onClose: () => widget.onClose?.call(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: _viewType,
        creationParams: _creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    }
    return UiKitView(
      viewType: _viewType,
      creationParams: _creationParams,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
    );
  }
}
