import 'package:flutter_test/flutter_test.dart';
import 'package:ezoic_flutter_cmp_sdk/ezoic_flutter_cmp_sdk.dart';

void main() {
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
}
