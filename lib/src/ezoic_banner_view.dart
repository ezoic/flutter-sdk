import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ezoic_ad_collapse.dart';
import 'ezoic_banner_size.dart';

/// Error delivered to [EzoicBannerView.onError] when a banner fails to load.
class EzoicBannerError {
  final String message;
  final int code;
  const EzoicBannerError(this.message, this.code);
}

/// Builds the per-view method-call handler that routes banner lifecycle events
/// from the platform channel to the supplied callbacks.
///
/// Factored out of [EzoicBannerView] so the dispatch logic can be exercised in
/// unit tests without instantiating a platform view (platform-view creation is
/// not available in plain widget tests). Unknown methods are ignored.
@visibleForTesting
Future<dynamic> Function(MethodCall call) createEzoicBannerMethodCallHandler({
  VoidCallback? onLoad,
  void Function(EzoicBannerError error)? onError,
  VoidCallback? onImpression,
  VoidCallback? onClick,
  VoidCallback? onOpen,
  VoidCallback? onClose,
  void Function(double width, double height)? onSizeChange,
}) {
  return (MethodCall call) async {
    switch (call.method) {
      case 'onLoad':
        onLoad?.call();
        break;
      case 'onError':
        final args =
            (call.arguments as Map?)?.cast<String, dynamic>() ?? const {};
        onError?.call(EzoicBannerError(
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
      case 'onSizeChange':
        final size = parseSizeChangeArguments(call.arguments);
        onSizeChange?.call(size.width, size.height);
        break;
    }
  };
}

/// A native Ezoic banner ad, embedded via a platform view.
///
/// Renders an `AndroidView` on Android and a `UiKitView` on iOS, forwarding
/// the native banner lifecycle callbacks to the supplied handlers. The widget
/// sizes itself to the requested [size]. When a load does not fill and
/// [collapseOnNoFill] is true, the widget collapses to [SizedBox.shrink].
class EzoicBannerView extends StatefulWidget {
  /// The Ezoic ad unit identifier. Crosses the bridge as a string and is
  /// coerced to a native `Int`.
  final String adUnitIdentifier;

  /// The requested banner size. Defaults to [EzoicBannerSize.mediumRectangle].
  final EzoicBannerSize size;

  /// Collapse the widget when a load fails and no ad is displayed.
  ///
  /// Defaults to `true`. Set to `false` to keep the reserved [size] on a
  /// no-fill.
  final bool collapseOnNoFill;

  /// Called when the banner successfully loads.
  final VoidCallback? onLoad;

  /// Called when the banner fails to load.
  final void Function(EzoicBannerError error)? onError;

  /// Called when the banner records an impression.
  final VoidCallback? onImpression;

  /// Called when the banner is clicked.
  final VoidCallback? onClick;

  /// Called when the banner presents a full-screen overlay.
  final VoidCallback? onOpen;

  /// Called when a presented full-screen overlay is dismissed.
  final VoidCallback? onClose;

  /// Called when the displayed ad size changes.
  ///
  /// Reports the creative size in dp/pt after a successful load, or `0, 0`
  /// when the view collapses.
  final void Function(double width, double height)? onSizeChange;

  const EzoicBannerView({
    super.key,
    required this.adUnitIdentifier,
    this.size = EzoicBannerSize.mediumRectangle,
    this.collapseOnNoFill = true,
    this.onLoad,
    this.onError,
    this.onImpression,
    this.onClick,
    this.onOpen,
    this.onClose,
    this.onSizeChange,
  });

  @override
  State<EzoicBannerView> createState() => _EzoicBannerViewState();
}

class _EzoicBannerViewState extends State<EzoicBannerView> {
  static const String _viewType = 'com.ezoic/ezoic_banner_view';

  bool _collapsed = false;

  Map<String, dynamic> get _creationParams => {
        'adUnitIdentifier': widget.adUnitIdentifier,
        'size': widget.size.toSizeString(),
        'collapseOnNoFill': widget.collapseOnNoFill,
      };

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('com.ezoic/ezoic_banner_view_$id');
    channel.setMethodCallHandler(createEzoicBannerMethodCallHandler(
      onLoad: () => widget.onLoad?.call(),
      onError: (error) => widget.onError?.call(error),
      onImpression: () => widget.onImpression?.call(),
      onClick: () => widget.onClick?.call(),
      onOpen: () => widget.onOpen?.call(),
      onClose: () => widget.onClose?.call(),
      onSizeChange: _handleSizeChange,
    ));
  }

  void _handleSizeChange(double width, double height) {
    widget.onSizeChange?.call(width, height);
    final collapsed = shouldCollapse(
      collapseOnNoFill: widget.collapseOnNoFill,
      height: height,
    );
    if (collapsed != _collapsed && mounted) {
      setState(() => _collapsed = collapsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_collapsed) {
      return const SizedBox.shrink();
    }

    final Widget platformView;
    if (defaultTargetPlatform == TargetPlatform.android) {
      platformView = AndroidView(
        viewType: _viewType,
        creationParams: _creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    } else {
      platformView = UiKitView(
        viewType: _viewType,
        creationParams: _creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    }

    return SizedBox(
      width: widget.size.width.toDouble(),
      height: widget.size.height.toDouble(),
      child: platformView,
    );
  }
}
