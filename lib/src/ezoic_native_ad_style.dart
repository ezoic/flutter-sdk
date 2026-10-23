import 'package:flutter/painting.dart';

/// Appearance of the native ad template shown by `EzoicNativeAdView`. Sizes
/// are in logical pixels (dp on Android, points on iOS). Unset colors follow
/// the platform theme, including dark mode.
///
/// `mediaHeight` is never below 120 and `adLabelText` is never blank: Google
/// requires a minimum media size and an ad label on native ads.
class EzoicNativeAdStyle {
  /// Card background. Default: transparent.
  final Color? backgroundColor;

  /// Card corner radius. Default: 0.
  final double? cornerRadius;

  /// Padding inside the card. Default: 8.
  final double? padding;

  final Color? headlineTextColor;

  /// Default: 16 (bold).
  final double? headlineTextSize;

  final Color? advertiserTextColor;

  /// Default: 12.
  final double? advertiserTextSize;

  final Color? bodyTextColor;

  /// Default: 14.
  final double? bodyTextSize;

  /// Call-to-action button fill. Default: the platform button.
  final Color? callToActionBackgroundColor;

  final Color? callToActionTextColor;

  /// Default: 14.
  final double? callToActionTextSize;

  /// Applies when [callToActionBackgroundColor] is set. Default: 4.
  final double? callToActionCornerRadius;

  /// Height of the media view, at least 120. Default: 175.
  final double? mediaHeight;

  /// Text of the ad label, e.g. "Sponsored". Default: "Ad".
  final String? adLabelText;

  /// Default: `Color(0xFF202124)`.
  final Color? adLabelTextColor;

  /// Default: `Color(0xFFFBBC04)`.
  final Color? adLabelBackgroundColor;

  const EzoicNativeAdStyle({
    this.backgroundColor,
    this.cornerRadius,
    this.padding,
    this.headlineTextColor,
    this.headlineTextSize,
    this.advertiserTextColor,
    this.advertiserTextSize,
    this.bodyTextColor,
    this.bodyTextSize,
    this.callToActionBackgroundColor,
    this.callToActionTextColor,
    this.callToActionTextSize,
    this.callToActionCornerRadius,
    this.mediaHeight,
    this.adLabelText,
    this.adLabelTextColor,
    this.adLabelBackgroundColor,
  });

  /// The key/value form the native SDKs parse: set values only, colors as ARGB
  /// ints.
  Map<String, Object> toMap() {
    final colors = <String, Color?>{
      'backgroundColor': backgroundColor,
      'headlineTextColor': headlineTextColor,
      'advertiserTextColor': advertiserTextColor,
      'bodyTextColor': bodyTextColor,
      'callToActionBackgroundColor': callToActionBackgroundColor,
      'callToActionTextColor': callToActionTextColor,
      'adLabelTextColor': adLabelTextColor,
      'adLabelBackgroundColor': adLabelBackgroundColor,
    };
    final sizes = <String, double?>{
      'cornerRadius': cornerRadius,
      'padding': padding,
      'headlineTextSize': headlineTextSize,
      'advertiserTextSize': advertiserTextSize,
      'bodyTextSize': bodyTextSize,
      'callToActionTextSize': callToActionTextSize,
      'callToActionCornerRadius': callToActionCornerRadius,
      'mediaHeight': mediaHeight,
    };
    return {
      for (final e in colors.entries)
        // `value` is the only ARGB accessor across the supported Flutter range.
        // ignore: deprecated_member_use
        if (e.value != null) e.key: e.value!.value,
      for (final e in sizes.entries)
        if (e.value != null && e.value!.isFinite) e.key: e.value!,
      if (adLabelText != null) 'adLabelText': adLabelText!,
    };
  }

  List<Object?> get _fields => [
        backgroundColor,
        cornerRadius,
        padding,
        headlineTextColor,
        headlineTextSize,
        advertiserTextColor,
        advertiserTextSize,
        bodyTextColor,
        bodyTextSize,
        callToActionBackgroundColor,
        callToActionTextColor,
        callToActionTextSize,
        callToActionCornerRadius,
        mediaHeight,
        adLabelText,
        adLabelTextColor,
        adLabelBackgroundColor,
      ];

  @override
  bool operator ==(Object other) {
    if (other is! EzoicNativeAdStyle) return false;
    final a = _fields;
    final b = other._fields;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_fields);
}
