import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ezoic_banner_size.dart';

/// Error delivered to [EzoicBannerView.onError] when a banner fails to load.
class EzoicBannerError {
  final String message;
  final int code;
  const EzoicBannerError(this.message, this.code);
}

/// A native Ezoic banner ad, embedded via a platform view.
///
/// Renders an `AndroidView` on Android and a `UiKitView` on iOS, forwarding
/// the native banner lifecycle callbacks to the supplied handlers.
class EzoicBannerView extends StatefulWidget {
  /// The Ezoic ad unit identifier. Crosses the bridge as a string and is
  /// coerced to a native `Int`.
  final String adUnitIdentifier;

  /// The requested banner size. Defaults to [EzoicBannerSize.mediumRectangle].
  final EzoicBannerSize size;

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

  const EzoicBannerView({
    super.key,
    required this.adUnitIdentifier,
    this.size = EzoicBannerSize.mediumRectangle,
    this.onLoad,
    this.onError,
    this.onImpression,
    this.onClick,
    this.onOpen,
    this.onClose,
  });

  @override
  State<EzoicBannerView> createState() => _EzoicBannerViewState();
}

class _EzoicBannerViewState extends State<EzoicBannerView> {
  static const String _viewType = 'com.ezoic/ezoic_banner_view';

  Map<String, dynamic> get _creationParams => {
        'adUnitIdentifier': widget.adUnitIdentifier,
        'size': widget.size.toSizeString(),
      };

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('com.ezoic/ezoic_banner_view_$id');
    channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onLoad':
          widget.onLoad?.call();
          break;
        case 'onError':
          final args = (call.arguments as Map).cast<String, dynamic>();
          widget.onError?.call(EzoicBannerError(
            args['message'] as String? ?? 'Unknown error',
            (args['code'] as num?)?.toInt() ?? 0,
          ));
          break;
        case 'onImpression':
          widget.onImpression?.call();
          break;
        case 'onClick':
          widget.onClick?.call();
          break;
        case 'onOpen':
          widget.onOpen?.call();
          break;
        case 'onClose':
          widget.onClose?.call();
          break;
      }
    });
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
