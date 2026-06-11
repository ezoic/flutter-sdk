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

  group('EzoicReward.fromShowResult', () {
    test('maps an earned reward', () {
      final reward = EzoicReward.fromShowResult(
        {'earned': true, 'type': 'coins', 'amount': 10},
      );
      expect(reward, isNotNull);
      expect(reward!.type, 'coins');
      expect(reward.amount, 10);
    });

    test('returns null when not earned', () {
      expect(
        EzoicReward.fromShowResult({'earned': false, 'type': '', 'amount': 0}),
        isNull,
      );
    });

    test('returns null for a missing result', () {
      expect(EzoicReward.fromShowResult(null), isNull);
    });

    test('defaults missing fields', () {
      final reward = EzoicReward.fromShowResult({'earned': true});
      expect(reward, isNotNull);
      expect(reward!.type, '');
      expect(reward.amount, 0);
    });
  });
}
