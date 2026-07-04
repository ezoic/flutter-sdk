import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Error delivered to [EzoicOutstreamAdView.onError] when an outstream ad fails
/// to load.
class EzoicOutstreamAdError {
  final String message;
  final int code;
  const EzoicOutstreamAdError(this.message, this.code);
}

/// Builds the per-view method-call handler that routes outstream ad lifecycle
/// events from the platform channel to the supplied callbacks.
///
/// Factored out of [EzoicOutstreamAdView] so the dispatch logic can be exercised
/// in unit tests without instantiating a platform view (platform-view creation
/// is not available in plain widget tests). Unknown methods are ignored.
@visibleForTesting
Future<dynamic> Function(MethodCall call)
    createEzoicOutstreamAdMethodCallHandler({
  VoidCallback? onLoad,
  void Function(EzoicOutstreamAdError error)? onError,
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
        onError?.call(EzoicOutstreamAdError(
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
/// Factored out of [EzoicOutstreamAdView] so the attach-then-load seam can be
/// exercised in unit tests without instantiating a platform view.
@visibleForTesting
void attachEzoicOutstreamAdChannel(
  MethodChannel channel, {
  VoidCallback? onLoad,
  void Function(EzoicOutstreamAdError error)? onError,
  VoidCallback? onImpression,
  VoidCallback? onClick,
  VoidCallback? onOpen,
  VoidCallback? onClose,
}) {
  channel.setMethodCallHandler(createEzoicOutstreamAdMethodCallHandler(
    onLoad: onLoad,
    onError: onError,
    onImpression: onImpression,
    onClick: onClick,
    onOpen: onOpen,
    onClose: onClose,
  ));
  unawaited(channel.invokeMethod<void>('load').catchError((_) {}));
}

/// An Ezoic outstream video ad, embedded via a platform view.
///
/// Outstream is a content-embedded video unit: the native SDK
/// (`EzoicOutstreamAdView` on both platforms) renders the video creative inline
/// through Google Ad Manager, forwarding the lifecycle callbacks to the
/// supplied handlers. Unlike the native ad unit there is no separate ad object
/// — the platform-view IS the ad.
///
/// Platform views fill their parent's constraints, so size the ad by wrapping
/// it in a [SizedBox] (or another constrained parent):
///
/// ```dart
/// SizedBox(
///   height: 200,
///   child: EzoicOutstreamAdView(
///     adUnitIdentifier: '12345',
///     onLoad: () => debugPrint('outstream loaded'),
///   ),
/// )
/// ```
class EzoicOutstreamAdView extends StatefulWidget {
  /// The Ezoic ad unit identifier. Crosses the bridge as a string and is
  /// coerced to a native `Int`.
  final String adUnitIdentifier;

  /// Called when the outstream ad successfully loads.
  final VoidCallback? onLoad;

  /// Called when the outstream ad fails to load.
  final void Function(EzoicOutstreamAdError error)? onError;

  /// Called when the outstream ad records an impression.
  final VoidCallback? onImpression;

  /// Called when the outstream ad is clicked.
  final VoidCallback? onClick;

  /// Called when a click on the outstream ad presents a full-screen overlay.
  final VoidCallback? onOpen;

  /// Called when a presented full-screen overlay is dismissed.
  final VoidCallback? onClose;

  const EzoicOutstreamAdView({
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
  State<EzoicOutstreamAdView> createState() => _EzoicOutstreamAdViewState();
}

class _EzoicOutstreamAdViewState extends State<EzoicOutstreamAdView> {
  static const String _viewType = 'com.ezoic/ezoic_outstream_ad_view';

  Map<String, dynamic> get _creationParams => {
        'adUnitIdentifier': widget.adUnitIdentifier,
      };

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('com.ezoic/ezoic_outstream_ad_view_$id');
    attachEzoicOutstreamAdChannel(
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
