import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ezoic_flutter_sdk/ezoic_flutter_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  group('createEzoicNativeAdMethodCallHandler', () {
    test('routes each lifecycle event to its callback', () async {
      var loaded = false;
      var impression = false;
      var clicked = false;
      var opened = false;
      var closed = false;

      final handler = createEzoicNativeAdMethodCallHandler(
        onLoad: () => loaded = true,
        onImpression: () => impression = true,
        onClick: () => clicked = true,
        onOpen: () => opened = true,
        onClose: () => closed = true,
      );

      await handler(const MethodCall('onLoad'));
      await handler(const MethodCall('onImpression'));
      await handler(const MethodCall('onClick'));
      await handler(const MethodCall('onOpen'));
      await handler(const MethodCall('onClose'));

      expect(loaded, isTrue);
      expect(impression, isTrue);
      expect(clicked, isTrue);
      expect(opened, isTrue);
      expect(closed, isTrue);
    });

    test('onError maps message and numeric code', () async {
      EzoicNativeAdError? error;
      final handler =
          createEzoicNativeAdMethodCallHandler(onError: (e) => error = e);

      await handler(const MethodCall('onError', {'message': 'boom', 'code': 7}));

      expect(error, isNotNull);
      expect(error!.message, 'boom');
      expect(error!.code, 7);
    });

    test('onError coerces a non-int (num) code to int', () async {
      EzoicNativeAdError? error;
      final handler =
          createEzoicNativeAdMethodCallHandler(onError: (e) => error = e);

      await handler(const MethodCall('onError', {'message': 'x', 'code': 3.0}));

      expect(error!.code, 3);
    });

    test('onError applies defaults when arguments are null', () async {
      EzoicNativeAdError? error;
      final handler =
          createEzoicNativeAdMethodCallHandler(onError: (e) => error = e);

      await handler(const MethodCall('onError'));

      expect(error, isNotNull);
      expect(error!.message, 'Unknown error');
      expect(error!.code, 0);
    });

    test('onError applies defaults when individual keys are missing', () async {
      EzoicNativeAdError? error;
      final handler =
          createEzoicNativeAdMethodCallHandler(onError: (e) => error = e);

      await handler(const MethodCall('onError', {'message': 'only message'}));

      expect(error!.message, 'only message');
      expect(error!.code, 0);
    });

    test('unknown methods are ignored', () async {
      var fired = false;
      final handler = createEzoicNativeAdMethodCallHandler(
        onLoad: () => fired = true,
        onError: (_) => fired = true,
        onImpression: () => fired = true,
        onClick: () => fired = true,
        onOpen: () => fired = true,
        onClose: () => fired = true,
      );

      await handler(const MethodCall('somethingUnhandled'));

      expect(fired, isFalse);
    });

    test('null callbacks are tolerated', () async {
      final handler = createEzoicNativeAdMethodCallHandler();

      // No callbacks supplied: dispatching any known event must not throw.
      await handler(const MethodCall('onLoad'));
      await handler(const MethodCall('onError', {'message': 'x', 'code': 1}));
      await handler(const MethodCall('onImpression'));
    });
  });

  group('attachEzoicNativeAdChannel', () {
    test('invokes load on the per-view channel after attaching the handler',
        () async {
      const channel = MethodChannel('com.ezoic/ezoic_native_ad_view_42');
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      attachEzoicNativeAdChannel(channel);
      // Let the unawaited invokeMethod future settle.
      await Future<void>.delayed(Duration.zero);

      expect(calls, hasLength(1));
      expect(calls.single.method, 'load');
    });

    test('swallows a synchronous platform-side load failure', () async {
      const channel = MethodChannel('com.ezoic/ezoic_native_ad_view_43');
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'EzoicAds', message: 'not initialized');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      // The rejected load future must not surface as an unhandled error.
      attachEzoicNativeAdChannel(channel);
      await Future<void>.delayed(Duration.zero);
    });
  });

  group('EzoicNativeAdView widget', () {
    testWidgets('builds an AndroidView with viewType and creationParams',
        (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: EzoicNativeAdView(adUnitIdentifier: '12345'),
        ),
      );

      final androidView = tester.widget<AndroidView>(find.byType(AndroidView));
      expect(androidView.viewType, 'com.ezoic/ezoic_native_ad_view');
      final params = androidView.creationParams as Map;
      expect(params['adUnitIdentifier'], '12345');
      expect(androidView.creationParamsCodec, isA<StandardMessageCodec>());
    });
  });
}
