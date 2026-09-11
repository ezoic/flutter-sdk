import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ezoic_flutter_sdk/ezoic_flutter_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('createEzoicBannerMethodCallHandler', () {
    test('routes onSizeChange to the callback', () async {
      double? width;
      double? height;
      final handler = createEzoicBannerMethodCallHandler(
        onSizeChange: (w, h) {
          width = w;
          height = h;
        },
      );

      await handler(const MethodCall('onSizeChange', {
        'width': 300,
        'height': 250,
      }));

      expect(width, 300);
      expect(height, 250);
    });

    test('onSizeChange coerces numeric values to double', () async {
      double? width;
      double? height;
      final handler = createEzoicBannerMethodCallHandler(
        onSizeChange: (w, h) {
          width = w;
          height = h;
        },
      );

      await handler(const MethodCall('onSizeChange', {
        'width': 320.0,
        'height': 50.0,
      }));

      expect(width, 320);
      expect(height, 50);
    });

    test('onSizeChange defaults missing keys to zero', () async {
      double? width;
      double? height;
      final handler = createEzoicBannerMethodCallHandler(
        onSizeChange: (w, h) {
          width = w;
          height = h;
        },
      );

      await handler(const MethodCall('onSizeChange'));

      expect(width, 0);
      expect(height, 0);
    });

    test('onError still routes message and code', () async {
      EzoicBannerError? error;
      final handler =
          createEzoicBannerMethodCallHandler(onError: (e) => error = e);

      await handler(const MethodCall('onError', {'message': 'boom', 'code': 7}));

      expect(error, isNotNull);
      expect(error!.message, 'boom');
      expect(error!.code, 7);
    });

    test('onError coerces a non-int (num) code to int', () async {
      EzoicBannerError? error;
      final handler =
          createEzoicBannerMethodCallHandler(onError: (e) => error = e);

      await handler(const MethodCall('onError', {'message': 'x', 'code': 3.0}));

      expect(error!.code, 3);
    });

    test('onError applies defaults when arguments are null', () async {
      EzoicBannerError? error;
      final handler =
          createEzoicBannerMethodCallHandler(onError: (e) => error = e);

      await handler(const MethodCall('onError'));

      expect(error, isNotNull);
      expect(error!.message, 'Unknown error');
      expect(error!.code, 0);
    });

    test('routes remaining lifecycle events', () async {
      var loaded = false;
      var impression = false;
      var clicked = false;
      var opened = false;
      var closed = false;

      final handler = createEzoicBannerMethodCallHandler(
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

    test('unknown methods are ignored', () async {
      var fired = false;
      final handler = createEzoicBannerMethodCallHandler(
        onLoad: () => fired = true,
        onError: (_) => fired = true,
        onSizeChange: (_, __) => fired = true,
      );

      await handler(const MethodCall('somethingUnhandled'));

      expect(fired, isFalse);
    });

    test('null callbacks are tolerated', () async {
      final handler = createEzoicBannerMethodCallHandler();

      await handler(const MethodCall('onLoad'));
      await handler(const MethodCall('onError', {'message': 'x', 'code': 1}));
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
      expect(shouldCollapse(collapseOnNoFill: true, height: 250), isFalse);
      expect(shouldCollapse(collapseOnNoFill: false, height: 250), isFalse);
    });

    test('does not collapse on zero height when collapseOnNoFill is false', () {
      expect(shouldCollapse(collapseOnNoFill: false, height: 0), isFalse);
    });
  });

  group('EzoicBannerSize.toSizeString', () {
    test('default mediumRectangle remains 300x250', () {
      expect(EzoicBannerSize.mediumRectangle.toSizeString(), '300x250');
    });
  });

  group('EzoicBannerView widget', () {
    testWidgets('sizes itself to the requested EzoicBannerSize', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: EzoicBannerView(adUnitIdentifier: '12345'),
        ),
      );

      final box = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(box.width, 300);
      expect(box.height, 250);
      expect(find.byType(AndroidView), findsOneWidget);
    });

    testWidgets('honors a non-default banner size', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: EzoicBannerView(
            adUnitIdentifier: '12345',
            size: EzoicBannerSize.banner,
          ),
        ),
      );

      final box = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(box.width, 320);
      expect(box.height, 50);
    });

    testWidgets('passes collapseOnNoFill and size in creationParams',
        (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: EzoicBannerView(
            adUnitIdentifier: '12345',
            collapseOnNoFill: false,
          ),
        ),
      );

      final androidView = tester.widget<AndroidView>(find.byType(AndroidView));
      expect(androidView.viewType, 'com.ezoic/ezoic_banner_view');
      final params = androidView.creationParams as Map;
      expect(params['adUnitIdentifier'], '12345');
      expect(params['size'], '300x250');
      expect(params['collapseOnNoFill'], isFalse);
      expect(androidView.creationParamsCodec, isA<StandardMessageCodec>());
    });

    testWidgets('defaults collapseOnNoFill to true in creationParams',
        (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: EzoicBannerView(adUnitIdentifier: '12345'),
        ),
      );

      final androidView = tester.widget<AndroidView>(find.byType(AndroidView));
      final params = androidView.creationParams as Map;
      expect(params['collapseOnNoFill'], isTrue);
    });
  });
}
