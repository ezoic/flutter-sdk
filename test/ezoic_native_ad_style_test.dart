import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ezoic_flutter_sdk/ezoic_flutter_sdk.dart';

void main() {
  group('EzoicNativeAdStyle.toMap', () {
    test('is empty for the default style', () {
      expect(const EzoicNativeAdStyle().toMap(), isEmpty);
    });

    test('sends colors as ARGB ints and keeps sizes and label text', () {
      const style = EzoicNativeAdStyle(
        backgroundColor: Color(0xFF1E1E2E),
        cornerRadius: 16,
        headlineTextColor: Color(0x80FFFFFF),
        headlineTextSize: 18,
        callToActionBackgroundColor: Color(0xFF89B4FA),
        mediaHeight: 150,
        adLabelText: 'Sponsored',
      );
      expect(style.toMap(), {
        'backgroundColor': 0xFF1E1E2E,
        'cornerRadius': 16.0,
        'headlineTextColor': 0x80FFFFFF,
        'headlineTextSize': 18.0,
        'callToActionBackgroundColor': 0xFF89B4FA,
        'mediaHeight': 150.0,
        'adLabelText': 'Sponsored',
      });
    });
  });

  group('EzoicNativeAdStyle equality', () {
    test('equal styles are equal and share a hash code', () {
      const a = EzoicNativeAdStyle(cornerRadius: 8, bodyTextColor: Color(0xFF000000));
      const b = EzoicNativeAdStyle(cornerRadius: 8, bodyTextColor: Color(0xFF000000));
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('a changed field makes styles unequal', () {
      expect(
        const EzoicNativeAdStyle(cornerRadius: 8),
        isNot(equals(const EzoicNativeAdStyle(cornerRadius: 9))),
      );
    });
  });
}
