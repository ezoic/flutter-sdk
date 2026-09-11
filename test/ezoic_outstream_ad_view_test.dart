import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ezoic_flutter_sdk/ezoic_flutter_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  group('createEzoicOutstreamAdMethodCallHandler', () {
    test('routes each lifecycle event to its callback', () async {
      var loaded = false;
      var impression = false;
      var clicked = false;
      var opened = false;
      var closed = false;

      final handler = createEzoicOutstreamAdMethodCallHandler(
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
      EzoicOutstreamAdError? error;
      final handler =
          createEzoicOutstreamAdMethodCallHandler(onError: (e) => error = e);

      await handler(const MethodCall('onError', {'message': 'boom', 'code': 7}));

      expect(error, isNotNull);
      expect(error!.message, 'boom');
      expect(error!.code, 7);
    });

    test('onError coerces a non-int (num) code to int', () async {
      EzoicOutstreamAdError? error;
      final handler =
          createEzoicOutstreamAdMethodCallHandler(onError: (e) => error = e);

      await handler(const MethodCall('onError', {'message': 'x', 'code': 3.0}));

      expect(error!.code, 3);
    });

    test('onError applies defaults when arguments are null', () async {
      EzoicOutstreamAdError? error;
      final handler =
          createEzoicOutstreamAdMethodCallHandler(onError: (e) => error = e);

      await handler(const MethodCall('onError'));

      expect(error, isNotNull);
      expect(error!.message, 'Unknown error');
      expect(error!.code, 0);
    });

    test('onError applies defaults when individual keys are missing', () async {
      EzoicOutstreamAdError? error;
      final handler =
          createEzoicOutstreamAdMethodCallHandler(onError: (e) => error = e);

      await handler(const MethodCall('onError', {'message': 'only message'}));

      expect(error!.message, 'only message');
      expect(error!.code, 0);
    });

    test('onSizeChange routes width and height as doubles', () async {
      double? width;
      double? height;
      final handler = createEzoicOutstreamAdMethodCallHandler(
        onSizeChange: (w, h) {
          width = w;
          height = h;
        },
      );

      await handler(
          const MethodCall('onSizeChange', {'width': 640, 'height': 360}));

      expect(width, isA<double>());
      expect(width, 640.0);
      expect(height, 360.0);
    });

    test('onSizeChange reports 0x0 on collapse and defaults missing keys',
        () async {
      double? width;
      double? height;
      final handler = createEzoicOutstreamAdMethodCallHandler(
        onSizeChange: (w, h) {
          width = w;
          height = h;
        },
      );

      await handler(const MethodCall('onSizeChange', {'width': 0, 'height': 0}));
      expect(width, 0.0);
      expect(height, 0.0);

      await handler(const MethodCall('onSizeChange'));
      expect(width, 0.0);
      expect(height, 0.0);
    });

    test('unknown methods are ignored', () async {
      var fired = false;
      final handler = createEzoicOutstreamAdMethodCallHandler(
        onLoad: () => fired = true,
        onError: (_) => fired = true,
        onImpression: () => fired = true,
        onClick: () => fired = true,
        onOpen: () => fired = true,
        onClose: () => fired = true,
        onSizeChange: (_, __) => fired = true,
      );

      await handler(const MethodCall('somethingUnhandled'));

      expect(fired, isFalse);
    });

    test('null callbacks are tolerated', () async {
      final handler = createEzoicOutstreamAdMethodCallHandler();

      // No callbacks supplied: dispatching any known event must not throw.
      await handler(const MethodCall('onLoad'));
      await handler(const MethodCall('onError', {'message': 'x', 'code': 1}));
      await handler(const MethodCall('onImpression'));
      await handler(const MethodCall('onSizeChange', {
        'width': 0,
        'height': 0,
      }));
    });
  });

  group('shouldCollapse', () {
    test('collapses on zero height when collapseOnNoFill is true', () {
      expect(shouldCollapse(collapseOnNoFill: true, height: 0), isTrue);
    });

    test('does not collapse on a non-zero height', () {
      expect(shouldCollapse(collapseOnNoFill: true, height: 200), isFalse);
      expect(shouldCollapse(collapseOnNoFill: false, height: 200), isFalse);
    });

    test('does not collapse on zero height when collapseOnNoFill is false', () {
      expect(shouldCollapse(collapseOnNoFill: false, height: 0), isFalse);
    });
  });

  group('attachEzoicOutstreamAdChannel', () {
    test('invokes load on the per-view channel after attaching the handler',
        () async {
      const channel = MethodChannel('com.ezoic/ezoic_outstream_ad_view_42');
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      attachEzoicOutstreamAdChannel(channel);
      // Let the unawaited invokeMethod future settle.
      await Future<void>.delayed(Duration.zero);

      expect(calls, hasLength(1));
      expect(calls.single.method, 'load');
    });

    test('swallows a synchronous platform-side load failure', () async {
      const channel = MethodChannel('com.ezoic/ezoic_outstream_ad_view_43');
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'EzoicAds', message: 'not initialized');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      // The rejected load future must not surface as an unhandled error.
      attachEzoicOutstreamAdChannel(channel);
      await Future<void>.delayed(Duration.zero);
    });
  });

  group('EzoicOutstreamAdView widget', () {
    testWidgets('builds an AndroidView with viewType and creationParams',
        (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: EzoicOutstreamAdView(adUnitIdentifier: '12345'),
        ),
      );

      final androidView = tester.widget<AndroidView>(find.byType(AndroidView));
      expect(androidView.viewType, 'com.ezoic/ezoic_outstream_ad_view');
      final params = androidView.creationParams as Map;
      expect(params['adUnitIdentifier'], '12345');
      expect(params['collapseOnNoFill'], isTrue);
      expect(androidView.creationParamsCodec, isA<StandardMessageCodec>());
    });

    testWidgets('forwards collapseOnNoFill: false to creationParams',
        (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: EzoicOutstreamAdView(
            adUnitIdentifier: '12345',
            collapseOnNoFill: false,
          ),
        ),
      );

      final androidView = tester.widget<AndroidView>(find.byType(AndroidView));
      final params = androidView.creationParams as Map;
      expect(params['collapseOnNoFill'], isFalse);
    });

    testWidgets('still fills a constrained parent when not collapsed',
        (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 320,
              height: 200,
              child: EzoicOutstreamAdView(adUnitIdentifier: '12345'),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(AndroidView)), const Size(320, 200));
    });
  });
}
