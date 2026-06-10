import 'package:flutter_test/flutter_test.dart';
import 'package:ezoic_flutter_sdk/ezoic_flutter_sdk.dart';

void main() {
  group('EzoicConfiguration', () {
    test('toMap includes domain and defaults', () {
      const config = EzoicConfiguration(domain: 'example.com');
      final map = config.toMap();
      expect(map['domain'], 'example.com');
      expect(map['autoReadConsent'], true);
      expect(map['requestATTBeforeAds'], true);
      expect(map['debugEnabled'], false);
      expect(map['testMode'], false);
    });

    test('toMap respects overrides', () {
      const config = EzoicConfiguration(domain: 'x.com', debugEnabled: true, testMode: true);
      final map = config.toMap();
      expect(map['debugEnabled'], true);
      expect(map['testMode'], true);
    });
  });

  group('EzoicBannerSize', () {
    test('standard sizes map to WxH', () {
      expect(EzoicBannerSize.mediumRectangle.toSizeString(), '300x250');
      expect(EzoicBannerSize.banner.toSizeString(), '320x50');
      expect(EzoicBannerSize.leaderboard.toSizeString(), '728x90');
    });
  });
}
