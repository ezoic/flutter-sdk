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
  });

  group('EzoicConsentOutcome.fromMap', () {
    test('parses the argument-less outcomes', () {
      expect(EzoicConsentOutcome.fromMap({'type': 'notRequired'}),
          const NotRequired());
      expect(EzoicConsentOutcome.fromMap({'type': 'alreadyDecided'}),
          const AlreadyDecided());
      expect(EzoicConsentOutcome.fromMap({'type': 'dismissed'}),
          const Dismissed());
      expect(EzoicConsentOutcome.fromMap({'type': 'alreadyPresenting'}),
          const AlreadyPresenting());
    });

    test('parses every decision', () {
      expect(
        EzoicConsentOutcome.fromMap({'type': 'decided', 'decision': 'acceptAll'}),
        const Decided(EzoicConsentDecision.acceptAll),
      );
      expect(
        EzoicConsentOutcome.fromMap({'type': 'decided', 'decision': 'rejectAll'}),
        const Decided(EzoicConsentDecision.rejectAll),
      );
      expect(
        EzoicConsentOutcome.fromMap({'type': 'decided', 'decision': 'custom'}),
        const Decided(EzoicConsentDecision.custom),
      );
    });

    test('parses a failure with its code and message', () {
      final outcome = EzoicConsentOutcome.fromMap(
          {'type': 'failed', 'code': 1003, 'message': 'Network error'});
      expect(outcome, const Failed(1003, 'Network error'));
      expect((outcome as Failed).code, 1003);
      expect(outcome.message, 'Network error');
    });

    test('defaults a failure missing its fields', () {
      expect(EzoicConsentOutcome.fromMap({'type': 'failed'}),
          const Failed(-1, 'Unknown error'));
    });

    test('coerces a failure with a non-numeric code', () {
      expect(
        EzoicConsentOutcome.fromMap(
            {'type': 'failed', 'code': '5001', 'message': 'Network error'}),
        const Failed(-1, 'Network error'),
      );
    });

    test('coerces a failure with a non-string message', () {
      expect(
        EzoicConsentOutcome.fromMap(
            {'type': 'failed', 'code': 1003, 'message': 7}),
        const Failed(1003, 'Unknown error'),
      );
    });

    test('truncates a fractional code', () {
      expect(
        EzoicConsentOutcome.fromMap(
            {'type': 'failed', 'code': 1003.0, 'message': 'x'}),
        const Failed(1003, 'x'),
      );
    });

    test('maps malformed input to failed(-1)', () {
      const unrecognized = Failed(-1, 'Unrecognized outcome');
      expect(EzoicConsentOutcome.fromMap(null), unrecognized);
      expect(EzoicConsentOutcome.fromMap('decided'), unrecognized);
      expect(EzoicConsentOutcome.fromMap(const <String, Object?>{}), unrecognized);
      expect(EzoicConsentOutcome.fromMap({'type': 'bogus'}), unrecognized);
      expect(EzoicConsentOutcome.fromMap({'type': 42}), unrecognized);
      expect(EzoicConsentOutcome.fromMap({'type': 'decided'}), unrecognized);
      expect(
        EzoicConsentOutcome.fromMap({'type': 'decided', 'decision': 'maybe'}),
        unrecognized,
      );
    });

    test('supports exhaustive switches', () {
      String describe(EzoicConsentOutcome o) => switch (o) {
            NotRequired() => 'notRequired',
            AlreadyDecided() => 'alreadyDecided',
            Decided(:final decision) => 'decided:${decision.name}',
            Dismissed() => 'dismissed',
            AlreadyPresenting() => 'alreadyPresenting',
            Failed(:final code) => 'failed:$code',
          };
      expect(describe(const Decided(EzoicConsentDecision.custom)),
          'decided:custom');
      expect(describe(const Failed(5001, 'x')), 'failed:5001');
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
