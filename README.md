# ezoic_flutter_sdk

Flutter plugin for the Ezoic Ads SDK (Prebid + Google Ad Manager banner,
native, outstream, instream, interstitial and rewarded ads). It wraps the
native SDKs: `EzoicAdsSDK` on iOS and `com.ezoic.sdk:ezoic-ads-sdk` on Android,
both 1.13.x.

## Requirements

- iOS 15.0+, built with Xcode 26+.
- Android `minSdk` 24+.
- Flutter 3.19+ (Dart 3.3+).

## Installation

The plugin is distributed from git (it is not on pub.dev). Pin a release tag
in your app's `pubspec.yaml`:

```yaml
dependencies:
  ezoic_flutter_sdk:
    git:
      url: https://github.com/ezoic/flutter-sdk.git
      ref: v1.13.0
```

**iOS.** The native SDK and Google Mobile Ads ship as static binaries, so your
app's `ios/Podfile` needs the iOS 15 platform and static framework linkage:

```ruby
platform :ios, '15.0'

target 'Runner' do
  use_frameworks! :linkage => :static
  # ...
end
```

Then run `pod install` in `ios/` (or let `flutter run` do it).

**Android.** The native SDK is resolved from Maven Central; nothing else to add.

## Initialize

Initialize once, early (for example in `main()` or your first screen's
`initState`), with the domain registered in your Ezoic dashboard:

```dart
import 'package:ezoic_flutter_sdk/ezoic_flutter_sdk.dart';

await EzoicAds.initialize(const EzoicConfiguration(domain: 'example.com'));
```

| `EzoicConfiguration` field | Default | Meaning |
|---|---|---|
| `domain` | required | Your domain as configured in the Ezoic dashboard |
| `autoReadConsent` | `true` | Read `IABTCF_*` / `IABGPP_*` consent written by a CMP |
| `subjectToCOPPA` | `false` | Treat the user as subject to COPPA |
| `requestATTBeforeAds` | `true` | iOS only: show the App Tracking Transparency prompt before ads |
| `debugEnabled` | `false` | Verbose native logging |
| `testMode` | `false` | Prebid debug and $0.00 Ezoic test ads on no-demand auctions (debug builds / simulators only) |
| `autoTrackPageviews` | `true` | Let the native SDK record pageviews for the host screen on its own ([Pageview Tracking](#pageview-tracking)) |
| `cmpEnabled` | `true` | Use the built-in TCF 2.4 consent dialog in GDPR regions ([Privacy & Consent](#privacy--consent)) |
| `autoPresentConsent` | `true` | After `initialize` succeeds, present the consent dialog once if it is required |

`initialize` throws a `PlatformException` if the native SDK fails to start.

## Privacy & Consent

### Built-in CMP (GDPR / TCF 2.4)

The native SDK includes an IAB TCF 2.4 consent management platform. It is on by
default (`cmpEnabled: true`) and only does anything for users in GDPR regions;
elsewhere nothing is shown and ads load as before.

> **If your app already runs another CMP (UMP, OneTrust, ...) you _must_ set
> `cmpEnabled: false`.** See [Using your own CMP](#using-your-own-cmp).

**Automatic presentation.** With the default `autoPresentConsent: true`, the
plugin calls `presentConsentIfRequired()` once, right after `initialize`
succeeds. The `initialize` future completes first, so your post-init code runs
and the dialog appears over it. The outcome is only logged (when
`debugEnabled` is on). If there is no foreground Activity / view controller at
that moment the plugin skips it; call `presentConsentIfRequired()` yourself
later. Outside GDPR regions, with `cmpEnabled: false`, when another CMP is
present, or when you called `setGDPRConsent` before `initialize`, it does
nothing.

**What ads do meanwhile.** In GDPR regions, ad loads wait while the consent
dialog is loading or on screen (at most 5 minutes in total), and up to
10 seconds while no dialog is in progress, then fail with
[`EzoicErrorCode.consentRequired`](#error-codes) (5001). They proceed without
a decision only when the dialog cannot be shown (a `Failed` outcome): ads then
carry `IABTCF_gdprApplies=1` and no TC string, which Google treats as limited
ads (and many Prebid bidders skip).

**Choosing the timing yourself.** Set `autoPresentConsent: false` and call
`presentConsentIfRequired()` when you are ready, for example from your first
screen. It is safe to call before `initialize` finishes (it waits for the init
response; if init fails you get `Failed`), and calling it again is harmless:
you get `AlreadyPresenting` while a dialog is in flight and `AlreadyDecided`
once a decision is stored. Re-present whenever `isConsentRequired()` is `true`
and no decision has been made (e.g. after `Dismissed` or `Failed`).

```dart
await EzoicAds.initialize(const EzoicConfiguration(
  domain: 'example.com',
  autoPresentConsent: false,
));

final outcome = await EzoicAds.presentConsentIfRequired();
switch (outcome) {
  case Decided(:final decision):
    debugPrint('User chose ${decision.name}');
  case Failed(:final code, :final message):
    debugPrint('Consent UI failed ($code): $message');
  case NotRequired() || AlreadyDecided() || Dismissed() || AlreadyPresenting():
    break;
}
```

**A persistent "Privacy settings" entry point is required.** TCF policy
requires users to be able to reopen the dialog and withdraw consent at any
time, so wire `presentConsentSettings()` to a menu item or button that is
always reachable:

```dart
TextButton(
  onPressed: EzoicAds.presentConsentSettings,
  child: const Text('Privacy settings'),
)
```

`presentConsentIfRequired()` and `presentConsentSettings()` always complete
with an `EzoicConsentOutcome`; they do not throw for consent results:

| Outcome | When |
|---|---|
| `NotRequired()` | GDPR doesn't apply, the built-in CMP is disabled (`cmpEnabled: false` or by Ezoic), another CMP owns consent, or consent is managed by the app (see [Manual consent](#manual-consent)) |
| `AlreadyDecided()` | A still-valid decision is stored; no dialog shown |
| `Decided(decision)` | The user chose `EzoicConsentDecision.acceptAll`, `rejectAll` or `custom`; the choice is saved |
| `Dismissed()` | The dialog closed without a choice; ads stay gated for this session. This can happen without user action (the dialog failed to start, or `resetConsent()` ran while it was loading or open) |
| `AlreadyPresenting()` | A consent dialog is already on screen, or one is being prepared with nothing on screen yet |
| `Failed(code, message)` | The dialog couldn't be shown (e.g. network error); ads proceed as limited ads (see above). `code` is the native `EzoicError` code, or `-1` when the plugin had no foreground Activity / view controller to present from |

- **`presentConsentSettings()`** always reopens the dialog in GDPR regions,
  even if the user already decided. It returns `NotRequired` outside GDPR
  regions, when `cmpEnabled` is `false`, when another CMP is present, or when
  consent is managed by the app.
- **`isConsentRequired()`** (`Future<bool?>`) is `null` until the init request
  completes, or when the server sent no consent information. It is `true`
  whenever GDPR applies and the built-in CMP is in charge (including after the
  user has decided) and `false` otherwise.
- **`resetConsent()`** deletes the stored decision so the dialog shows again
  (ads re-gate until the user decides). Keys written by another CMP are left
  alone.
- Decisions are stored as standard `IABTCF_*` keys (`UserDefaults` on iOS,
  default `SharedPreferences` on Android), so Prebid, GAM and other IAB-aware
  SDKs read them as usual.

### Using your own CMP

Set `cmpEnabled: false`. The native SDK then reads your CMP's `IABTCF_*` /
`IABGPP_*` keys exactly as before. The built-in CMP also stands down
automatically if it finds `IABTCF_CmpSdkID` set to another CMP's ID.

```dart
await EzoicAds.initialize(const EzoicConfiguration(
  domain: 'example.com',
  cmpEnabled: false,
));
```

### Manual consent

You can also set consent programmatically. Manual consent and the built-in CMP
are mutually exclusive: once `setGDPRConsent` is called, or when
`autoReadConsent` is `false`, the built-in CMP doesn't gate ad loads, show its
dialog or write `IABTCF_*` keys.

The `setGDPRConsent` override lasts for the current process only. **Call
`setGDPRConsent` before `EzoicAds.initialize` on every launch, or set
`cmpEnabled: false`.** Otherwise each cold start begins with the built-in CMP
in charge until your call lands. The SDK does not write your consent to
`IABTCF_*` keys for GMA or other SDKs in the app, so your own CMP must write
those keys.

```dart
await EzoicAds.setGDPRConsent(true, 'CPXxRfAPXxRfAAfKABENB-CgAAAAAAAAAAYgAAAAAAAA');
await EzoicAds.setGPPConsent('DBACNYA~...', '7');
await EzoicAds.setSubjectToCOPPA(true);
await EzoicAds.initialize(const EzoicConfiguration(domain: 'example.com'));
```

## Pageview Tracking

Ezoic reports app traffic per *screen*, the way it reports a site per URL:
`https://<your domain>/<bundle id>/<screen label>`.

The native SDK tracks pageviews automatically for native screens (Activities /
view controllers), but a Flutter app is a single native screen
(`MainActivity` / `FlutterViewController`), so automatic pageviews only carry
that host label. Label your routes with `EzoicAds.trackPageview(screen)`, for
example from a `NavigatorObserver`:

```dart
class EzoicPageviewObserver extends NavigatorObserver {
  void _track(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (route is PageRoute && name != null) EzoicAds.trackPageview(name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _track(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _track(newRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _track(previousRoute);
  }
}

MaterialApp(
  navigatorObservers: [EzoicPageviewObserver()],
  // ...
);
```

Labels: use `/` for hierarchy (`members/profile`), spaces become `-`,
punctuation is dropped, case is kept. The label is also attached to every ad
request on that screen, so impressions and pageviews report under the same
page. A labelled pageview takes precedence over the automatic one for the same
navigation. `trackPageview()` without a label (or with an empty one) records
an unlabelled pageview.

If you label every screen yourself, set `autoTrackPageviews: false` so the
native SDK never records host-screen pageviews on its own.

## Error codes

`EzoicErrorCode.consentRequired` (5001) is reported when an ad load fails
because GDPR applies and the user has not made a consent choice yet (see
[Privacy & Consent](#privacy--consent)). It arrives as `code` on
`EzoicBannerError`, `EzoicNativeAdError`, `EzoicOutstreamAdError` (the
`onError` callbacks), on `EzoicInterstitialAdError` / `EzoicInstreamAdError`
thrown by `load`, and as `PlatformException.details` when
`EzoicRewardedAd.load` fails.

```dart
onError: (error) {
  if (error.code == EzoicErrorCode.consentRequired) {
    // Ask for consent again, e.g. EzoicAds.presentConsentIfRequired().
  }
},
```

## API

`EzoicAds` (all static):

- `initialize(EzoicConfiguration)` → `Future<void>`
- `setGDPRConsent(bool applies, [String? consentString])`, `setGPPConsent([String? gppString, String? sectionIds])`, `setSubjectToCOPPA(bool)` → `Future<void>`
- `trackPageview([String? screen])` → `Future<bool>`
- `presentConsentIfRequired()`, `presentConsentSettings()` → `Future<EzoicConsentOutcome>`
- `isConsentRequired()` → `Future<bool?>`
- `resetConsent()` → `Future<void>`

Types: `EzoicConfiguration`, `EzoicConsentOutcome` (`NotRequired`,
`AlreadyDecided`, `Decided`, `Dismissed`, `AlreadyPresenting`, `Failed`),
`EzoicConsentDecision`, `EzoicErrorCode`.

Ad formats: `EzoicBannerView`, `EzoicNativeAdView`, `EzoicOutstreamAdView`,
`EzoicInstreamAd`, `EzoicInterstitialAd`, `EzoicRewardedAd` (below).

## Banner Ads

`EzoicBannerView` embeds a native Ezoic banner. The widget sizes itself to the
requested `EzoicBannerSize` (default `mediumRectangle` / 300×250). When a load
does not fill and `collapseOnNoFill` is true (the default), the widget collapses
to zero size (`SizedBox.shrink()`), so an empty ad box is not left on screen.

```dart
import 'package:ezoic_flutter_sdk/ezoic_flutter_sdk.dart';

EzoicBannerView(
  adUnitIdentifier: '12345',
  size: EzoicBannerSize.banner,
  collapseOnNoFill: true,
  onSizeChange: (width, height) => debugPrint('banner size $width x $height'),
  onLoad: () => debugPrint('banner loaded'),
  onError: (error) => debugPrint('banner failed: ${error.message}'),
)
```

`onSizeChange` reports the displayed creative size in dp/pt after a successful
load, or `0 × 0` when the view collapses. Set `collapseOnNoFill: false` to keep
the reserved size on a no-fill.

## Native Ads

`EzoicNativeAdView` loads a native ad through the native SDKs and renders it in
an SDK-built template (a `NativeAdView` with the ad's headline, icon,
advertiser, media, body and call-to-action). It is a platform view, so it fills
its parent's constraints — wrap it in a `SizedBox` (or another constrained
parent) to size it:

```dart
import 'package:ezoic_flutter_sdk/ezoic_flutter_sdk.dart';

SizedBox(
  height: 320,
  child: EzoicNativeAdView(
    adUnitIdentifier: '12345',
    onLoad: () => debugPrint('native ad loaded'),
    onError: (error) => debugPrint('native ad failed: ${error.message}'),
    onImpression: () => debugPrint('native ad impression'),
    onClick: () => debugPrint('native ad clicked'),
    onOpen: () => debugPrint('native ad opened an overlay'),
    onClose: () => debugPrint('native ad overlay closed'),
  ),
)
```

The template and the underlying native ad are built and destroyed by the plugin
with the platform view's lifecycle — no manual `destroy()` call is required.

## Outstream Video

`EzoicOutstreamAdView` loads an outstream video ad through the native SDKs and
renders it inline through Google Ad Manager. Like the native ad view it is a
platform view, so it fills its parent's constraints — wrap it in a `SizedBox`
(or another constrained parent) to size it. When a load does not fill and
`collapseOnNoFill` is true (the default), the widget collapses to
`SizedBox.shrink()`.

```dart
import 'package:ezoic_flutter_sdk/ezoic_flutter_sdk.dart';

SizedBox(
  height: 200,
  child: EzoicOutstreamAdView(
    adUnitIdentifier: '12345',
    collapseOnNoFill: true,
    onSizeChange: (width, height) =>
        debugPrint('outstream size $width x $height'),
    onLoad: () => debugPrint('outstream ad loaded'),
    onError: (error) => debugPrint('outstream ad failed: ${error.message}'),
    onImpression: () => debugPrint('outstream ad impression'),
    onClick: () => debugPrint('outstream ad clicked'),
    onOpen: () => debugPrint('outstream ad opened an overlay'),
    onClose: () => debugPrint('outstream ad overlay closed'),
  ),
)
```

The video view and its underlying native ad are built and destroyed by the
plugin with the platform view's lifecycle — no manual `destroy()` call is
required.

## Instream Video

`EzoicInstreamAd` is a view-less controller for instream video. Instream video
runs inside your app's OWN video content: the host app owns the video player
and the Google IMA SDK. The controller renders nothing — its deliverable is a
GAM VAST ad-tag URL you feed to your IMA `AdsRequest`.

```dart
import 'package:ezoic_flutter_sdk/ezoic_flutter_sdk.dart';

final instream = EzoicInstreamAd('12345');

try {
  final tagUrl = await instream.load(contentUrl: playingVideoUrl);
  // Feed tagUrl to your IMA AdsRequest.adTagUrl and request the preroll.
} on EzoicInstreamAdError catch (e) {
  debugPrint('instream load failed: ${e.message}');
}

// When IMA reports an ad error, walk the floor waterfall to the next tag.
// A null result means the waterfall is exhausted — give up on the preroll.
final next = await instream.getNextAdTagUrl();

// When IMA reports the ad STARTED, fire the Ezoic impression pixel.
await instream.reportImpression();

// Instream is multi-use: the controller lives (and can prefetch the next tag)
// until you explicitly release it.
await instream.destroy();
```

Unlike the interstitial unit, `EzoicInstreamAd` is not single-use: keep the
controller and reuse it across loads, then call `destroy()` when done.

