import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ezoic_flutter_sdk/ezoic_flutter_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mainChannel = MethodChannel('com.ezoic/ezoic_flutter_sdk');
  const codec = StandardMethodCodec();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void setMainHandler(Future<dynamic>? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(mainChannel, handler);
  }

  // Delivers an event on a per-ad rewarded event channel, mimicking the native
  // plugin invoking the Dart-side event handler.
  Future<void> sendEvent(String id, String method, [dynamic args]) async {
    await messenger.handlePlatformMessage(
      'com.ezoic/ezoic_rewarded_ad_$id',
      codec.encodeMethodCall(MethodCall(method, args)),
      (ByteData? _) {},
    );
  }

  tearDown(() {
    messenger.setMockMethodCallHandler(mainChannel, null);
  });

  group('EzoicRewardedAd.load', () {
    test('sends loadRewardedAd with the ad unit identifier', () async {
      final calls = <MethodCall>[];
      setMainHandler((call) async {
        calls.add(call);
        return null;
      });

      final ad = await EzoicRewardedAd.load('123');
      addTearDown(ad.destroy);

      expect(calls, hasLength(1));
      expect(calls.single.method, 'loadRewardedAd');
      expect((calls.single.arguments as Map)['adUnitIdentifier'], '123');
    });

    test('rethrows when the native load fails', () async {
      setMainHandler((call) async {
        throw PlatformException(code: 'EzoicAds', message: 'no fill');
      });

      await expectLater(
        EzoicRewardedAd.load('123'),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('EzoicRewardedAd.show', () {
    test('resolves the earned reward on dismiss and auto-destroys', () async {
      setMainHandler((call) async {
        if (call.method == 'showRewardedAd') {
          await sendEvent('123', 'onUserEarnedReward', {'type': 'coins', 'amount': 5});
          await sendEvent('123', 'onDismissed');
          return {'earned': true, 'type': 'coins', 'amount': 5};
        }
        return null;
      });

      final ad = await EzoicRewardedAd.load('123');
      var shownAfterDismiss = false;
      ad.onShown = () => shownAfterDismiss = true;

      final reward = await ad.show();
      expect(reward, isNotNull);
      expect(reward!.type, 'coins');
      expect(reward.amount, 5);

      // Auto-destroy on dismiss detaches the event handler.
      await sendEvent('123', 'onShown');
      expect(shownAfterDismiss, isFalse);
    });

    test('throws and auto-destroys on failedToShow', () async {
      setMainHandler((call) async {
        if (call.method == 'showRewardedAd') {
          await sendEvent('123', 'onFailedToShow', {'message': 'boom', 'code': 7});
          throw PlatformException(code: 'EzoicAds', message: 'boom');
        }
        return null;
      });

      final ad = await EzoicRewardedAd.load('123');
      EzoicRewardedAdError? failed;
      var shownAfterFail = false;
      ad.onFailedToShow = (error) => failed = error;
      ad.onShown = () => shownAfterFail = true;

      await expectLater(ad.show(), throwsA(isA<PlatformException>()));
      expect(failed, isNotNull);
      expect(failed!.message, 'boom');
      expect(failed!.code, 7);

      // Auto-destroy on failedToShow detaches the handler: further events drop.
      await sendEvent('123', 'onShown');
      expect(shownAfterFail, isFalse);
    });
  });

  group('EzoicRewardedAd double-load / double-show guards', () {
    test('rejects a second load for an already loaded/loading id', () async {
      final loaded = <String>{};
      setMainHandler((call) async {
        if (call.method == 'loadRewardedAd') {
          final id = (call.arguments as Map)['adUnitIdentifier'] as String;
          if (!loaded.add(id)) {
            throw PlatformException(
              code: 'EzoicAds',
              message: 'An ad is already loaded/loading for ad unit $id',
            );
          }
          return null;
        }
        return null;
      });

      final ad = await EzoicRewardedAd.load('777');
      addTearDown(ad.destroy);

      await expectLater(
        EzoicRewardedAd.load('777'),
        throwsA(isA<PlatformException>()),
      );
    });

    test('rejects a second show while the first is in flight; first settles',
        () async {
      Completer<void>? firstGate;
      setMainHandler((call) async {
        switch (call.method) {
          case 'loadRewardedAd':
            return null;
          case 'showRewardedAd':
            if (firstGate != null) {
              throw PlatformException(
                code: 'EzoicAds',
                message: 'A show is already in progress for ad unit 123',
              );
            }
            final gate = Completer<void>();
            firstGate = gate;
            await gate.future;
            await sendEvent('123', 'onDismissed');
            return {'earned': false, 'type': '', 'amount': 0};
        }
        return null;
      });

      final ad = await EzoicRewardedAd.load('123');
      final first = ad.show();
      // Let the first show handler register its in-flight gate.
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await expectLater(ad.show(), throwsA(isA<PlatformException>()));

      firstGate!.complete();
      // First resolves normally (dismissed without earning => null reward).
      expect(await first, isNull);
    });
  });

  group('EzoicRewardedAd events', () {
    test('routes each lifecycle event to its callback', () async {
      setMainHandler((call) async => null);
      final ad = await EzoicRewardedAd.load('456');
      addTearDown(ad.destroy);

      var shown = false;
      var impression = false;
      var clicked = false;
      EzoicReward? earned;
      EzoicRewardedAdError? failed;

      ad.onShown = () => shown = true;
      ad.onImpression = () => impression = true;
      ad.onClicked = () => clicked = true;
      ad.onUserEarnedReward = (reward) => earned = reward;
      ad.onFailedToShow = (error) => failed = error;

      await sendEvent('456', 'onShown');
      await sendEvent('456', 'onImpression');
      await sendEvent('456', 'onClicked');
      await sendEvent('456', 'onUserEarnedReward', {'type': 'gems', 'amount': 3});
      await sendEvent('456', 'onFailedToShow', {'message': 'x', 'code': 3});

      expect(shown, isTrue);
      expect(impression, isTrue);
      expect(clicked, isTrue);
      expect(earned, isNotNull);
      expect(earned!.type, 'gems');
      expect(earned!.amount, 3);
      expect(failed, isNotNull);
      expect(failed!.code, 3);
    });
  });
}
