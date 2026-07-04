import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ezoic_flutter_sdk/ezoic_flutter_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mainChannel = MethodChannel('com.ezoic/ezoic_flutter_sdk');

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void setMainHandler(Future<dynamic>? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(mainChannel, handler);
  }

  tearDown(() {
    messenger.setMockMethodCallHandler(mainChannel, null);
  });

  group('EzoicInstreamAd.load', () {
    test('resolves the tag URL and passes the ad unit id and contentUrl',
        () async {
      final calls = <MethodCall>[];
      setMainHandler((call) async {
        calls.add(call);
        return 'https://pubads.g.doubleclick.net/gampad/ads?iu=/1/x';
      });

      final ad = EzoicInstreamAd('123');
      final tag = await ad.load(contentUrl: 'https://example.com/video.mp4');

      expect(tag, 'https://pubads.g.doubleclick.net/gampad/ads?iu=/1/x');
      expect(calls, hasLength(1));
      expect(calls.single.method, 'loadInstreamAd');
      final args = calls.single.arguments as Map;
      expect(args['adUnitIdentifier'], '123');
      expect(args['contentUrl'], 'https://example.com/video.mp4');
    });

    test('passes a null contentUrl when omitted', () async {
      MethodCall? seen;
      setMainHandler((call) async {
        seen = call;
        return 'tag';
      });

      final ad = EzoicInstreamAd('123');
      await ad.load();

      final args = seen!.arguments as Map;
      expect(args['contentUrl'], isNull);
    });

    test('throws EzoicInstreamAdError with an int code on PlatformException',
        () async {
      setMainHandler((call) async {
        throw PlatformException(code: 'EzoicAds', message: 'no fill', details: 7);
      });

      final ad = EzoicInstreamAd('123');

      EzoicInstreamAdError? thrown;
      try {
        await ad.load();
      } on EzoicInstreamAdError catch (e) {
        thrown = e;
      }

      expect(thrown, isNotNull);
      expect(thrown!.message, 'no fill');
      expect(thrown.code, 7);
    });

    test('parses a string details code', () async {
      setMainHandler((call) async {
        throw PlatformException(
            code: 'EzoicAds', message: 'boom', details: '42');
      });

      final ad = EzoicInstreamAd('123');

      EzoicInstreamAdError? thrown;
      try {
        await ad.load();
      } on EzoicInstreamAdError catch (e) {
        thrown = e;
      }

      expect(thrown, isNotNull);
      expect(thrown!.code, 42);
    });
  });

  group('EzoicInstreamAd.getNextAdTagUrl', () {
    test('returns the tag URL when the native side provides one', () async {
      setMainHandler((call) async {
        if (call.method == 'getInstreamNextAdTagUrl') return 'next-tag';
        return null;
      });

      final ad = EzoicInstreamAd('123');
      expect(await ad.getNextAdTagUrl(), 'next-tag');
    });

    test('returns null when the waterfall is exhausted', () async {
      setMainHandler((call) async => null);

      final ad = EzoicInstreamAd('123');
      expect(await ad.getNextAdTagUrl(), isNull);
    });
  });

  group('EzoicInstreamAd.reportImpression', () {
    test('passes revenueUsd and the ad unit id', () async {
      MethodCall? seen;
      setMainHandler((call) async {
        seen = call;
        return null;
      });

      final ad = EzoicInstreamAd('123');
      await ad.reportImpression(revenueUsd: 1.25);

      expect(seen!.method, 'reportInstreamImpression');
      final args = seen!.arguments as Map;
      expect(args['adUnitIdentifier'], '123');
      expect(args['revenueUsd'], 1.25);
    });

    test('passes a null revenueUsd when omitted', () async {
      MethodCall? seen;
      setMainHandler((call) async {
        seen = call;
        return null;
      });

      final ad = EzoicInstreamAd('123');
      await ad.reportImpression();

      final args = seen!.arguments as Map;
      expect(args['revenueUsd'], isNull);
    });
  });

  group('EzoicInstreamAd.destroy', () {
    test('invokes destroyInstreamAd with the ad unit id', () async {
      MethodCall? seen;
      setMainHandler((call) async {
        seen = call;
        return null;
      });

      final ad = EzoicInstreamAd('123');
      await ad.destroy();

      expect(seen!.method, 'destroyInstreamAd');
      expect((seen!.arguments as Map)['adUnitIdentifier'], '123');
    });
  });

  group('EzoicInstreamAd duplicate load', () {
    test('passes a second load straight through (guard is native-side)',
        () async {
      final calls = <MethodCall>[];
      setMainHandler((call) async {
        calls.add(call);
        return 'tag';
      });

      final ad = EzoicInstreamAd('123');
      await ad.load();
      await ad.load();

      expect(calls.where((c) => c.method == 'loadInstreamAd'), hasLength(2));
    });
  });
}
