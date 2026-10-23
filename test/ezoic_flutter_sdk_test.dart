import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ezoic_flutter_sdk/ezoic_flutter_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mainChannel = MethodChannel('com.ezoic/ezoic_flutter_sdk');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  void mockMain(Object? Function(MethodCall call) reply) {
    messenger.setMockMethodCallHandler(mainChannel, (call) async {
      calls.add(call);
      return reply(call);
    });
  }

  tearDown(() {
    calls.clear();
    messenger.setMockMethodCallHandler(mainChannel, null);
    EzoicAds.resetInitializationForTesting();
  });

  group('EzoicAds.initialize', () {
    test('sends the new configuration keys with their defaults', () async {
      mockMain((_) => null);
      await EzoicAds.initialize(const EzoicConfiguration(domain: 'example.com'));
      expect(calls.single.method, 'initialize');
      final args = calls.single.arguments as Map;
      expect(args['domain'], 'example.com');
      expect(args['autoTrackPageviews'], true);
      expect(args['cmpEnabled'], true);
      expect(args['autoPresentConsent'], true);
    });

    const config = EzoicConfiguration(domain: 'example.com');
    PlatformException alreadyInitialized() => PlatformException(
        code: 'EzoicAds', message: 'Ezoic SDK is already initialized.', details: 1002);

    test('resolves when native is already initialized (hot restart)', () async {
      mockMain((call) {
        if (call.method == 'initialize') throw alreadyInitialized();
        return {'type': 'notRequired'};
      });
      await EzoicAds.initialize(config);
      await pumpEventQueue();
      expect(calls.map((c) => c.method), ['initialize', 'presentConsentIfRequired']);
    });

    test('skips the consent prompt on re-init when autoPresentConsent is false', () async {
      mockMain((call) => throw alreadyInitialized());
      await EzoicAds.initialize(
          const EzoicConfiguration(domain: 'example.com', autoPresentConsent: false));
      await pumpEventQueue();
      expect(calls.map((c) => c.method), ['initialize']);
    });

    test('shares one native call between concurrent and later calls', () async {
      final release = Completer<void>();
      messenger.setMockMethodCallHandler(mainChannel, (call) async {
        calls.add(call);
        await release.future;
        return null;
      });
      final first = EzoicAds.initialize(config);
      final second = EzoicAds.initialize(config);
      expect(identical(first, second), isTrue);
      release.complete();
      await Future.wait([first, second]);
      await EzoicAds.initialize(config);
      expect(calls, hasLength(1));
    });

    test('retries after a failed initialize', () async {
      var attempts = 0;
      mockMain((call) {
        if (++attempts == 1) {
          throw PlatformException(code: 'EzoicAds', message: 'network', details: 4001);
        }
        return null;
      });
      await expectLater(EzoicAds.initialize(config), throwsA(isA<PlatformException>()));
      await EzoicAds.initialize(config);
      expect(calls.map((c) => c.method), ['initialize', 'initialize']);
    });
  });

  group('EzoicAds.trackPageview', () {
    test('sends a null screen when called without a label', () async {
      mockMain((_) => true);
      expect(await EzoicAds.trackPageview(), true);
      expect(calls.single.method, 'trackPageview');
      expect(calls.single.arguments, {'screen': null});
    });

    test('sends the screen label', () async {
      mockMain((_) => true);
      expect(await EzoicAds.trackPageview('Home'), true);
      expect(calls.single.arguments, {'screen': 'Home'});
    });

    test('resolves false when native returns null', () async {
      mockMain((_) => null);
      expect(await EzoicAds.trackPageview('Home'), false);
    });
  });

  group('EzoicConfiguration', () {
    test('toMap includes domain and defaults', () {
      const config = EzoicConfiguration(domain: 'example.com');
      final map = config.toMap();
      expect(map['domain'], 'example.com');
      expect(map['autoReadConsent'], true);
      expect(map['requestATTBeforeAds'], true);
      expect(map['debugEnabled'], false);
      expect(map['testMode'], false);
      expect(map['autoTrackPageviews'], true);
      expect(map['cmpEnabled'], true);
      expect(map['autoPresentConsent'], true);
    });

    test('toMap respects overrides', () {
      const config = EzoicConfiguration(domain: 'x.com', debugEnabled: true, testMode: true);
      final map = config.toMap();
      expect(map['debugEnabled'], true);
      expect(map['testMode'], true);
    });

    test('toMap carries pageview and consent overrides', () {
      const config = EzoicConfiguration(
        domain: 'x.com',
        autoTrackPageviews: false,
        cmpEnabled: false,
        autoPresentConsent: false,
      );
      final map = config.toMap();
      expect(map['autoTrackPageviews'], false);
      expect(map['cmpEnabled'], false);
      expect(map['autoPresentConsent'], false);
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
