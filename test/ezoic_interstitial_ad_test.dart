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

  // Delivers an event on a per-ad interstitial event channel, mimicking the
  // native plugin invoking the Dart-side event handler.
  Future<void> sendEvent(String id, String method, [dynamic args]) async {
    await messenger.handlePlatformMessage(
      'com.ezoic/ezoic_interstitial_ad_$id',
      codec.encodeMethodCall(MethodCall(method, args)),
      (ByteData? _) {},
    );
  }

  tearDown(() {
    messenger.setMockMethodCallHandler(mainChannel, null);
  });

  group('EzoicInterstitialAd.load', () {
    test('sends loadInterstitialAd with the ad unit identifier', () async {
      final calls = <MethodCall>[];
      setMainHandler((call) async {
        calls.add(call);
        return null;
      });

      final ad = await EzoicInterstitialAd.load('123');
      addTearDown(ad.destroy);

      expect(calls, hasLength(1));
      expect(calls.single.method, 'loadInterstitialAd');
      expect(
        (calls.single.arguments as Map)['adUnitIdentifier'],
        '123',
      );
    });

    test('rethrows when the native load fails', () async {
      setMainHandler((call) async {
        throw PlatformException(code: 'EzoicAds', message: 'no fill');
      });

      await expectLater(
        EzoicInterstitialAd.load('123'),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('EzoicInterstitialAd.show', () {
    test('resolves when a dismissed event is delivered and auto-destroys',
        () async {
      var dismissed = false;
      var shownAfterDismiss = false;

      setMainHandler((call) async {
        if (call.method == 'showInterstitialAd') {
          await sendEvent('123', 'onDismissed');
        }
        return null;
      });

      final ad = await EzoicInterstitialAd.load('123');
      ad.onDismissed = () => dismissed = true;
      ad.onShown = () => shownAfterDismiss = true;

      await ad.show();
      expect(dismissed, isTrue);

      // Auto-destroy on dismiss detaches the event handler: further events are
      // dropped rather than routed to callbacks.
      await sendEvent('123', 'onShown');
      expect(shownAfterDismiss, isFalse);
    });

    test('throws EzoicInterstitialAdError on failedToShow', () async {
      EzoicInterstitialAdError? callbackError;

      setMainHandler((call) async {
        if (call.method == 'showInterstitialAd') {
          await sendEvent('123', 'onFailedToShow', {
            'message': 'boom',
            'code': 7,
          });
          throw PlatformException(
            code: 'EzoicAds',
            message: 'boom',
            details: 7,
          );
        }
        return null;
      });

      final ad = await EzoicInterstitialAd.load('123');
      addTearDown(ad.destroy);
      ad.onFailedToShow = (error) => callbackError = error;

      EzoicInterstitialAdError? thrown;
      try {
        await ad.show();
      } on EzoicInterstitialAdError catch (e) {
        thrown = e;
      }

      expect(thrown, isNotNull);
      expect(thrown!.message, 'boom');
      expect(thrown.code, 7);

      expect(callbackError, isNotNull);
      expect(callbackError!.message, 'boom');
      expect(callbackError!.code, 7);
    });
  });

  group('EzoicInterstitialAd double-load / double-show guards', () {
    test('rejects a second load for an already loaded/loading id', () async {
      final loaded = <String>{};
      setMainHandler((call) async {
        if (call.method == 'loadInterstitialAd') {
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

      final ad = await EzoicInterstitialAd.load('777');
      addTearDown(ad.destroy);

      await expectLater(
        EzoicInterstitialAd.load('777'),
        throwsA(isA<PlatformException>()),
      );
    });

    test('rejects a second show while the first is in flight; first settles',
        () async {
      Completer<void>? firstGate;
      setMainHandler((call) async {
        switch (call.method) {
          case 'loadInterstitialAd':
            return null;
          case 'showInterstitialAd':
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
            return null;
        }
        return null;
      });

      final ad = await EzoicInterstitialAd.load('123');
      final first = ad.show();
      // Let the first show handler register its in-flight gate.
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await expectLater(ad.show(), throwsA(isA<EzoicInterstitialAdError>()));

      firstGate!.complete();
      await first; // resolves normally, unaffected by the rejected second call
    });
  });

  group('EzoicInterstitialAd events', () {
    test('auto-destroys on failedToShow and drops later events', () async {
      setMainHandler((call) async {
        if (call.method == 'showInterstitialAd') {
          await sendEvent('123', 'onFailedToShow', {'message': 'boom', 'code': 7});
          throw PlatformException(code: 'EzoicAds', message: 'boom', details: 7);
        }
        return null;
      });

      final ad = await EzoicInterstitialAd.load('123');
      var failed = false;
      var shownAfterFail = false;
      ad.onFailedToShow = (_) => failed = true;
      ad.onShown = () => shownAfterFail = true;

      await expectLater(ad.show(), throwsA(isA<EzoicInterstitialAdError>()));
      expect(failed, isTrue);

      // Auto-destroy on failedToShow detaches the handler: further events drop.
      await sendEvent('123', 'onShown');
      expect(shownAfterFail, isFalse);
    });

    test('routes each lifecycle event to its callback', () async {
      setMainHandler((call) async => null);
      final ad = await EzoicInterstitialAd.load('456');
      addTearDown(ad.destroy);

      var shown = false;
      var impression = false;
      var clicked = false;
      EzoicInterstitialAdError? failed;

      ad.onShown = () => shown = true;
      ad.onImpression = () => impression = true;
      ad.onClicked = () => clicked = true;
      ad.onFailedToShow = (error) => failed = error;

      await sendEvent('456', 'onShown');
      await sendEvent('456', 'onImpression');
      await sendEvent('456', 'onClicked');
      await sendEvent('456', 'onFailedToShow', {'message': 'x', 'code': 3});

      expect(shown, isTrue);
      expect(impression, isTrue);
      expect(clicked, isTrue);
      expect(failed, isNotNull);
      expect(failed!.code, 3);
    });
  });

  group('EzoicInterstitialAd.destroy', () {
    test('releases the native ad of an unshown ad, once', () async {
      final calls = <MethodCall>[];
      setMainHandler((call) async {
        calls.add(call);
        return null;
      });

      final ad = await EzoicInterstitialAd.load('123');
      ad.destroy();
      ad.destroy();
      await pumpEventQueue();

      final destroys = calls.where((c) => c.method == 'destroyInterstitialAd').toList();
      expect(destroys, hasLength(1));
      expect((destroys.single.arguments as Map)['adUnitIdentifier'], '123');
    });

    test('lets the same ad unit load again after destroy', () async {
      final loaded = <String>{};
      setMainHandler((call) async {
        final id = (call.arguments as Map)['adUnitIdentifier'] as String;
        if (call.method == 'loadInterstitialAd') {
          if (!loaded.add(id)) {
            throw PlatformException(code: 'EzoicAds', message: 'already loaded/loading');
          }
        } else if (call.method == 'destroyInterstitialAd') {
          loaded.remove(id);
        }
        return null;
      });

      final first = await EzoicInterstitialAd.load('123');
      first.destroy();
      final second = await EzoicInterstitialAd.load('123');
      addTearDown(second.destroy);
      expect(second.adUnitIdentifier, '123');
    });

    test('swallows a native destroy failure', () async {
      setMainHandler((call) async {
        if (call.method == 'destroyInterstitialAd') {
          throw PlatformException(code: 'EzoicAds', message: 'gone');
        }
        return null;
      });

      final ad = await EzoicInterstitialAd.load('123');
      ad.destroy();
      await pumpEventQueue();
    });

    test('skips the native call once the ad was shown', () async {
      final calls = <MethodCall>[];
      setMainHandler((call) async {
        calls.add(call);
        return call.method == 'showInterstitialAd' ? null : null;
      });

      final ad = await EzoicInterstitialAd.load('123');
      await ad.show();
      ad.destroy();
      await pumpEventQueue();

      expect(calls.where((c) => c.method == 'destroyInterstitialAd'), isEmpty);
    });

    test('skips the native call after a terminal event', () async {
      final calls = <MethodCall>[];
      setMainHandler((call) async {
        calls.add(call);
        return null;
      });

      for (final event in ['onDismissed', 'onFailedToShow']) {
        final ad = await EzoicInterstitialAd.load('123');
        await sendEvent('123', event, {'message': 'x', 'code': 1});
        ad.destroy();
      }
      await pumpEventQueue();

      expect(calls.where((c) => c.method == 'destroyInterstitialAd'), isEmpty);
    });

    test('a spent ad does not detach a newer ad for the same unit', () async {
      setMainHandler((call) async => null);

      final old = await EzoicInterstitialAd.load('123');
      await sendEvent('123', 'onDismissed');
      final current = await EzoicInterstitialAd.load('123');
      addTearDown(current.destroy);
      var shown = false;
      current.onShown = () => shown = true;

      old.destroy();
      await sendEvent('123', 'onShown');
      expect(shown, isTrue);
    });
  });
}
