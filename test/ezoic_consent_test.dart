import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ezoic_flutter_cmp_sdk/ezoic_flutter_cmp_sdk.dart' as cmp;
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
  });

  group('re-exported outcome types', () {
    test('are the ezoic_flutter_cmp_sdk types', () {
      const cmp.EzoicConsentOutcome outcome = Failed(1001, 'x');
      expect(outcome, const cmp.Failed(1001, 'x'));
      expect(const Decided(EzoicConsentDecision.acceptAll),
          const cmp.Decided(cmp.EzoicConsentDecision.acceptAll));
      expect(EzoicConsentOutcome.fromMap({'type': 'notRequired'}),
          isA<cmp.NotRequired>());
    });
  });

  group('EzoicErrorCode', () {
    test('consentRequired is 5001', () {
      expect(EzoicErrorCode.consentRequired, 5001);
    });
  });

  group('EzoicAds consent methods', () {
    test('presentConsentIfRequired maps the native outcome', () async {
      mockMain((_) => {'type': 'decided', 'decision': 'rejectAll'});
      final outcome = await EzoicAds.presentConsentIfRequired();
      expect(calls.single.method, 'presentConsentIfRequired');
      expect(outcome, const Decided(EzoicConsentDecision.rejectAll));
    });

    test('presentConsentSettings maps the native outcome', () async {
      mockMain((_) =>
          {'type': 'failed', 'code': -1, 'message': 'No foreground Activity'});
      final outcome = await EzoicAds.presentConsentSettings();
      expect(calls.single.method, 'presentConsentSettings');
      expect(outcome, const Failed(-1, 'No foreground Activity'));
    });

    test('a null native reply becomes an unrecognized failure', () async {
      mockMain((_) => null);
      expect(await EzoicAds.presentConsentIfRequired(),
          const Failed(-1, 'Unrecognized outcome'));
    });

    test('a PlatformException becomes a failed outcome', () async {
      mockMain((_) => throw PlatformException(code: 'EzoicAds', message: 'boom'));
      expect(await EzoicAds.presentConsentIfRequired(), const Failed(-1, 'boom'));
      expect(await EzoicAds.presentConsentSettings(), const Failed(-1, 'boom'));
    });

    test('a PlatformException without a message falls back to its string form',
        () async {
      mockMain((_) => throw PlatformException(code: 'EzoicAds'));
      final outcome = await EzoicAds.presentConsentSettings();
      expect(outcome, isA<Failed>());
      expect((outcome as Failed).code, -1);
      expect(outcome.message, contains('EzoicAds'));
    });

    test('a missing plugin becomes a failed outcome', () async {
      messenger.setMockMethodCallHandler(mainChannel, null);
      final ifRequired = await EzoicAds.presentConsentIfRequired();
      final settings = await EzoicAds.presentConsentSettings();
      for (final outcome in [ifRequired, settings]) {
        expect(outcome, isA<Failed>());
        expect((outcome as Failed).code, -1);
        expect(outcome.message, contains('presentConsent'));
      }
    });

    test('isConsentRequired passes true, false and null through', () async {
      for (final value in [true, false, null]) {
        mockMain((_) => value);
        expect(await EzoicAds.isConsentRequired(), value);
      }
      expect(calls.map((c) => c.method).toSet(), {'isConsentRequired'});
    });

    test('resetConsent invokes the native method', () async {
      mockMain((_) => null);
      await EzoicAds.resetConsent();
      expect(calls.single.method, 'resetConsent');
    });
  });
}
