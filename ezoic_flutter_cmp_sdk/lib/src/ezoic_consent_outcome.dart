/// Which button the user closed the consent dialog with.
enum EzoicConsentDecision { acceptAll, rejectAll, custom }

/// Result of `presentConsentIfRequired` and `presentConsentSettings`, on
/// `EzoicCmp` and on `EzoicAds` (package `ezoic_flutter_sdk`).
///
/// In a covered US state, `presentConsentSettings` opens the US privacy
/// settings: [Decided] with [EzoicConsentDecision.acceptAll] means saved not
/// opted out, [EzoicConsentDecision.rejectAll] saved opted out, and
/// [Dismissed] closed without saving.
sealed class EzoicConsentOutcome {
  const EzoicConsentOutcome();

  /// Parses the map sent by the native plugins. Never throws: input that is
  /// not a recognized outcome becomes `Failed(-1, 'Unrecognized outcome')`,
  /// and a `failed` map with a missing or mistyped field gets code `-1` /
  /// message `'Unknown error'`.
  factory EzoicConsentOutcome.fromMap(Object? map) {
    const unrecognized = Failed(-1, 'Unrecognized outcome');
    if (map is! Map) return unrecognized;
    switch (map['type']) {
      case 'notRequired':
        return const NotRequired();
      case 'alreadyDecided':
        return const AlreadyDecided();
      case 'dismissed':
        return const Dismissed();
      case 'alreadyPresenting':
        return const AlreadyPresenting();
      case 'decided':
        final decision = map['decision'];
        for (final value in EzoicConsentDecision.values) {
          if (value.name == decision) return Decided(value);
        }
        return unrecognized;
      case 'failed':
        final code = map['code'];
        final message = map['message'];
        return Failed(
          code is num ? code.toInt() : -1,
          message is String ? message : 'Unknown error',
        );
      default:
        return unrecognized;
    }
  }
}

/// GDPR does not apply, the built-in CMP is disabled, another CMP owns
/// consent, or consent is managed by the app. `presentConsentIfRequired`
/// also returns this in covered US states, where the CMP shows its US notice
/// on its own.
final class NotRequired extends EzoicConsentOutcome {
  const NotRequired();

  @override
  bool operator ==(Object other) => other is NotRequired;

  @override
  int get hashCode => (NotRequired).hashCode;

  @override
  String toString() => 'NotRequired()';
}

/// A still-valid decision is stored; no dialog was shown.
final class AlreadyDecided extends EzoicConsentOutcome {
  const AlreadyDecided();

  @override
  bool operator ==(Object other) => other is AlreadyDecided;

  @override
  int get hashCode => (AlreadyDecided).hashCode;

  @override
  String toString() => 'AlreadyDecided()';
}

/// The user made a choice, which has been saved.
final class Decided extends EzoicConsentOutcome {
  final EzoicConsentDecision decision;

  const Decided(this.decision);

  @override
  bool operator ==(Object other) =>
      other is Decided && other.decision == decision;

  @override
  int get hashCode => Object.hash(Decided, decision);

  @override
  String toString() => 'Decided(${decision.name})';
}

/// The dialog closed without a choice; ads stay gated for this session. This
/// can happen without user action (the dialog failed to start, or
/// `resetConsent` ran while it was loading or open).
final class Dismissed extends EzoicConsentOutcome {
  const Dismissed();

  @override
  bool operator ==(Object other) => other is Dismissed;

  @override
  int get hashCode => (Dismissed).hashCode;

  @override
  String toString() => 'Dismissed()';
}

/// A consent dialog is already on screen, or one is being prepared with
/// nothing on screen yet.
final class AlreadyPresenting extends EzoicConsentOutcome {
  const AlreadyPresenting();

  @override
  bool operator ==(Object other) => other is AlreadyPresenting;

  @override
  int get hashCode => (AlreadyPresenting).hashCode;

  @override
  String toString() => 'AlreadyPresenting()';
}

/// The dialog could not be shown. Ads (and other IAB-aware SDKs) then see
/// `IABTCF_gdprApplies=1` and no TC string, which Google treats as limited ads.
///
/// [code] is the native error code: `1001` not initialized (or, for
/// `EzoicCmp`, a domain Ezoic refused), `2001` network, `4001` render,
/// `5002` invalid consent. It is `-1` when the plugin had no foreground
/// Activity / view controller to present from, the platform call failed, or
/// the native error carried no code. Code `1001` writes nothing, and `-1`
/// never reaches the CMP: after either, ads stay gated (with `EzoicAds`); call
/// `presentConsentIfRequired` again once a screen is showing.
final class Failed extends EzoicConsentOutcome {
  final int code;
  final String message;

  const Failed(this.code, this.message);

  @override
  bool operator ==(Object other) =>
      other is Failed && other.code == code && other.message == message;

  @override
  int get hashCode => Object.hash(Failed, code, message);

  @override
  String toString() => 'Failed($code, $message)';
}
