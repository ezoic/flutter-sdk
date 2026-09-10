import 'package:flutter_test/flutter_test.dart';
import 'package:ezoic_flutter_sdk/ezoic_flutter_sdk.dart';
import 'package:flutter/services.dart';

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
      const config = EzoicConfiguration(
        domain: 'x.com',
        debugEnabled: true,
        testMode: true,
      );
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
      final reward = EzoicReward.fromShowResult({
        'earned': true,
        'type': 'coins',
        'amount': 10,
      });
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

  group('EzoicAds pageview identity', () {
    const channel = MethodChannel('com.ezoic/ezoic_flutter_sdk');
    final binding = TestWidgetsFlutterBinding.ensureInitialized();

    tearDown(() {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    test('reads current pageview and visitor ids', () async {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        switch (call.method) {
          case 'getPageviewId':
            return 'pv-123';
          case 'getVisitorId':
            return 'visit-456';
        }
        fail('unexpected method ${call.method}');
      });

      expect(await EzoicAds.pageviewId, 'pv-123');
      expect(await EzoicAds.visitorId, 'visit-456');
    });

    test('maps trackPageviewWithIds result and null failure', () async {
      var shouldFail = false;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method != 'trackPageviewWithIds') {
          fail('unexpected method ${call.method}');
        }
        if (shouldFail) return null;
        return {'pageviewId': 'pv-123', 'visitorId': 'visit-456'};
      });

      final pageview = await EzoicAds.trackPageviewWithIds();
      expect(pageview, isNotNull);
      expect(pageview!.pageviewId, 'pv-123');
      expect(pageview.visitorId, 'visit-456');

      shouldFail = true;
      expect(await EzoicAds.trackPageviewWithIds(), isNull);
    });
  });
}
