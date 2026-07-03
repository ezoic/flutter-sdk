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

  group('EzoicInterstitialAd events', () {
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
}
