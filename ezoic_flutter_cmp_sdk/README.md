# ezoic_flutter_cmp_sdk

Flutter plugin for the Ezoic CMP, for **Ezoic publishers whose app doesn't use
Ezoic ads**. It is the consent management platform built into the Ezoic Ads
SDK, on its own:

- **GDPR regions:** the IAB TCF 2.4 consent dialog. Decisions are stored as
  the standard `IABTCF_*` keys.
- **Covered US states** (California, Colorado, Connecticut, Delaware, Florida,
  Iowa, Montana, Nebraska, New Hampshire, New Jersey, Oregon, Tennessee, Texas,
  Utah and Virginia): a non-blocking privacy notice and a "Do Not Sell My
  Information" choice. The choice is stored as the standard IAB GPP keys
  (`IABGPP_*`).

Other SDKs in the app (Google Mobile Ads, Prebid and other IAB-aware SDKs) read
these keys from `UserDefaults` on iOS and the default `SharedPreferences` on
Android. Whether GDPR applies, and whether the dialog is on, come from your
Ezoic settings for the domain you pass to `initialize`.

It wraps the native CMP 1.22.0: `com.ezoic.sdk:ezoic-cmp-sdk` on Android and
`EzoicCmpSDK` from [ezoic-swift-sdk-dist](https://github.com/ezoic/ezoic-swift-sdk-dist)
on iOS.

> **Using Ezoic ads?** Use [`ezoic_flutter_sdk`](../) instead. It already
> includes this CMP through `EzoicAds`, whose consent methods have the same
> names and outcomes. Use one entry point, not both: if an app initializes both
> `EzoicAds` and `EzoicCmp`, `EzoicAds` takes over the same CMP and its stored
> decision.

## Requirements

- iOS 15.0+, built with Xcode 26.2+.
- Android `minSdk` 24+.
- Flutter 3.41+ (Dart 3.11+).
- Your domain must be an Ezoic publisher's. Ezoic refuses other domains, and
  the CMP then does nothing (see [Outcomes](#outcomes)).

## Installation

The package is distributed from git, from the same repository and tag as
`ezoic_flutter_sdk`:

```yaml
dependencies:
  ezoic_flutter_cmp_sdk:
    git:
      url: https://github.com/ezoic/flutter-sdk.git
      ref: v1.22.0
      path: ezoic_flutter_cmp_sdk
```

**iOS.** Set your app's minimum deployment target to iOS 15.0 (Runner target >
General > Minimum Deployments in Xcode). With Swift Package Manager (Flutter's
default from 3.44), nothing else is needed. With CocoaPods, set
`platform :ios, '15.0'` in `ios/Podfile`. `pod install` then downloads
`EzoicCmpSDKBinary.xcframework` from the
[ezoic-swift-sdk-dist release](https://github.com/ezoic/ezoic-swift-sdk-dist/releases)
and checks its SHA-256, so the first `pod install` needs network access to
GitHub.

**Android.** The native CMP is resolved from Maven Central; nothing else to add.

## Usage

```dart
import 'package:ezoic_flutter_cmp_sdk/ezoic_flutter_cmp_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
  await EzoicCmp.initialize('example.com');
}
```

`initialize` returns at once, and your Ezoic settings load in the background.
With the default `autoPresentConsent: true`, the plugin then calls
`presentConsentIfRequired()` once, which waits for the settings and shows the
dialog where GDPR applies. In covered US states the CMP shows its US notice on
its own.

| `EzoicCmpConfiguration` field | Default | Meaning |
|---|---|---|
| `cmpEnabled` | `true` | Run the CMP. Set `false` if your app runs another CMP |
| `autoReadConsent` | `true` | `false` means the app manages consent itself: the CMP never presents or writes keys |
| `debugEnabled` | `false` | Write the CMP's debug and info lines to the platform log (logcat tag `EzoicCmp`, iOS subsystem `com.ezoic.cmp.sdk`) |
| `autoPresentConsent` | `true` | Right after `initialize`, present the consent dialog once if it is required |

```dart
await EzoicCmp.initialize(
  'example.com',
  const EzoicCmpConfiguration(autoPresentConsent: false),
);
final outcome = await EzoicCmp.presentConsentIfRequired();
```

**A persistent "Privacy choices" entry point is required.** Show one unless
`isPrivacyOptionsRequired()` is `false`: it is `true` in a GDPR region or a
covered US state, and `null` while not known yet. Call
`presentConsentSettings()` from it, which returns `NotRequired` if there is
nothing to show. It reopens the TCF dialog in GDPR
regions, and opens the US privacy settings in covered US states:

```dart
FutureBuilder<bool?>(
  future: EzoicCmp.isPrivacyOptionsRequired(),
  // null means not known yet: keep the entry point until it is false.
  builder: (context, snapshot) => snapshot.data != false
      ? TextButton(
          onPressed: EzoicCmp.presentConsentSettings,
          child: const Text('Privacy choices'),
        )
      : const SizedBox.shrink(),
)
```

## API

`EzoicCmp` (all static):

- `initialize(String domain, [EzoicCmpConfiguration])` → `Future<void>`.
  Repeat calls are ignored, so a hot restart is harmless.
- `presentConsentIfRequired()`, `presentConsentSettings()` → `Future<EzoicConsentOutcome>`.
  They never throw.
- `isConsentRequired()` → `Future<bool?>`: whether GDPR applies and this CMP
  handles consent. It is `null` before `initialize`, while the settings load,
  or when none could be loaded (refused domain, blocked country, offline with
  no cached settings).
- `isPrivacyOptionsRequired()` → `Future<bool?>`: whether to show the
  "Privacy choices" entry point. It is `null` while unknown.
- `resetConsent()` → `Future<void>`: deletes the stored decision and US choice,
  so the dialog (or the US notice, at the next launch) shows again. Keys
  written by another CMP or by the app are left alone.

## Outcomes

| Outcome | When |
|---|---|
| `NotRequired()` | GDPR doesn't apply (including covered US states, for `presentConsentIfRequired`), the CMP is off, another CMP owns consent, or the app manages consent |
| `AlreadyDecided()` | A still-valid decision is stored; no dialog shown |
| `Decided(decision)` | The user chose `EzoicConsentDecision.acceptAll`, `rejectAll` or `custom`; the choice is saved. From the US privacy settings: `acceptAll` = not opted out, `rejectAll` = opted out |
| `Dismissed()` | The dialog closed without a choice (US privacy settings: closed without saving) |
| `AlreadyPresenting()` | A consent dialog is already on screen, or being prepared |
| `Failed(code, message)` | The dialog couldn't be shown. `code`: `1001` not initialized or domain refused by Ezoic (nothing is written), `2001` network, `4001` render, `5002` invalid consent; `-1` when there was no foreground Activity / view controller or the platform call failed |

## Using your own CMP

Set `cmpEnabled: false` (or don't use this package). The CMP also stands down
on its own when another CMP has already written `IABTCF_CmpSdkID`, or when
another CMP wrote the `IABGPP_*` keys.
