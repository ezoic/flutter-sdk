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
          const Failed(-1, ''));
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
