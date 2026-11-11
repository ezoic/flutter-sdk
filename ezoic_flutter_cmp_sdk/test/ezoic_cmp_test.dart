import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ezoic_flutter_cmp_sdk/ezoic_flutter_cmp_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.ezoic/ezoic_flutter_cmp_sdk');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  void mockCmp(Object? Function(MethodCall call) reply) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return reply(call);
    });
  }

  tearDown(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('EzoicCmp.initialize', () {
    test('sends the domain and the default configuration', () async {
      mockCmp((_) => null);
      await EzoicCmp.initialize('example.com');
      expect(calls.single.method, 'initialize');
      expect(calls.single.arguments, {
        'domain': 'example.com',
        'cmpEnabled': true,
        'autoReadConsent': true,
        'debugEnabled': false,
        'autoPresentConsent': true,
      });
    });

    test('forwards a custom configuration', () async {
      mockCmp((_) => null);
      await EzoicCmp.initialize(
        'example.com',
        const EzoicCmpConfiguration(
          cmpEnabled: false,
          autoReadConsent: false,
          debugEnabled: true,
          autoPresentConsent: false,
        ),
      );
      expect(calls.single.arguments, {
        'domain': 'example.com',
        'cmpEnabled': false,
        'autoReadConsent': false,
        'debugEnabled': true,
        'autoPresentConsent': false,
      });
    });

    test('rethrows a native rejection', () async {
      mockCmp((_) => throw PlatformException(code: 'EzoicCmp', message: 'bad'));
      await expectLater(
          EzoicCmp.initialize(''), throwsA(isA<PlatformException>()));
    });
  });

  group('EzoicCmp consent methods', () {
    test('presentConsentIfRequired maps the native outcome', () async {
      mockCmp((_) => {'type': 'decided', 'decision': 'acceptAll'});
      expect(await EzoicCmp.presentConsentIfRequired(),
          const Decided(EzoicConsentDecision.acceptAll));
      expect(calls.single.method, 'presentConsentIfRequired');
    });

    test('presentConsentSettings maps a refused domain to Failed(1001)',
        () async {
      mockCmp((_) => {
            'type': 'failed',
            'code': 1001,
            'message': 'The Ezoic CMP has not been initialized.',
          });
      expect(await EzoicCmp.presentConsentSettings(),
          const Failed(1001, 'The Ezoic CMP has not been initialized.'));
      expect(calls.single.method, 'presentConsentSettings');
    });

    test('a PlatformException becomes a failed outcome', () async {
      mockCmp((_) => throw PlatformException(code: 'EzoicCmp', message: 'boom'));
      expect(await EzoicCmp.presentConsentIfRequired(), const Failed(-1, 'boom'));
      expect(await EzoicCmp.presentConsentSettings(), const Failed(-1, 'boom'));
    });

    test('a missing plugin becomes a failed outcome', () async {
      for (final outcome in [
        await EzoicCmp.presentConsentIfRequired(),
        await EzoicCmp.presentConsentSettings(),
      ]) {
        expect(outcome, isA<Failed>());
        expect((outcome as Failed).code, -1);
      }
    });

    test('isConsentRequired passes true, false and null through', () async {
      for (final value in [true, false, null]) {
        mockCmp((_) => value);
        expect(await EzoicCmp.isConsentRequired(), value);
      }
      expect(calls.map((c) => c.method).toSet(), {'isConsentRequired'});
    });

    test('isPrivacyOptionsRequired passes true, false and null through',
        () async {
      for (final value in [true, false, null]) {
        mockCmp((_) => value);
        expect(await EzoicCmp.isPrivacyOptionsRequired(), value);
      }
      expect(calls.map((c) => c.method).toSet(), {'isPrivacyOptionsRequired'});
    });

    test('resetConsent invokes the native method', () async {
      mockCmp((_) => null);
      await EzoicCmp.resetConsent();
      expect(calls.single.method, 'resetConsent');
    });
  });
}
