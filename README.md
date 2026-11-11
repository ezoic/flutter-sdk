# ezoic_flutter_sdk

Flutter plugin for the Ezoic Ads SDK (Prebid + Google Ad Manager banner,
native, outstream, instream, interstitial and rewarded ads). It wraps the
native SDKs: `EzoicAdsSDK` 1.22.x on iOS and `com.ezoic.sdk:ezoic-ads-sdk`
1.22.0 on Android. The built-in consent management (CMP) comes from the
sibling package [`ezoic_flutter_cmp_sdk`](ezoic_flutter_cmp_sdk/), which this
package depends on; apps that only need the CMP can use that package alone.

## Requirements

- iOS 15.0+, built with Xcode 26.2+.
- Android `minSdk` 24+, Kotlin 2.2+.
- Flutter 3.41+ (Dart 3.11+).

## Installation

The plugin is distributed from git (it is not on pub.dev). Pin a release tag
in your app's `pubspec.yaml`:

```yaml
dependencies:
  ezoic_flutter_sdk:
    git:
      url: https://github.com/ezoic/flutter-sdk.git
      ref: v1.22.0
```

This also brings in `ezoic_flutter_cmp_sdk` from the same tag; don't add it to
your `pubspec.yaml` as well (see [Standalone CMP](#standalone-cmp)).

**iOS.** Set your app's minimum deployment target to iOS 15.0 (Runner target >
General > Minimum Deployments in Xcode, which sets `IPHONEOS_DEPLOYMENT_TARGET`
in `ios/Runner.xcodeproj`; new Flutter apps default to 13.0). The plugin
supports both Swift Package Manager and CocoaPods.

*Swift Package Manager* is Flutter's default from 3.44; on 3.41 to 3.43 turn
it on with `flutter config --enable-swift-package-manager`. Nothing else to
add: `flutter run` / `flutter build ios` resolves the native SDK from
[ezoic-swift-sdk-dist](https://github.com/ezoic/ezoic-swift-sdk-dist).

*CocoaPods* is used when Swift Package Manager is off
(`flutter config --no-enable-swift-package-manager`, or
`enable-swift-package-manager: false` under `flutter: config:` in your app's
`pubspec.yaml`). Set the iOS 15 platform in your app's `ios/Podfile`, then run
`pod install` in `ios/` (or let `flutter run` do it):

```ruby
platform :ios, '15.0'
```

With CocoaPods the plugin no longer uses the `EzoicAdsSDK` pod from CocoaPods
trunk (which stopped at 1.19.1). `pod install` downloads the native SDK
(`EzoicAdsSDKBinary.xcframework`, and `EzoicCmpSDKBinary.xcframework` through
`ezoic_flutter_cmp_sdk`) from the
[ezoic-swift-sdk-dist release](https://github.com/ezoic/ezoic-swift-sdk-dist/releases)
for the pinned version and checks each file's SHA-256, so the first
`pod install` needs network access to GitHub. It also installs the
`PrebidMobile`, `Google-Mobile-Ads-SDK` and `AmazonPublisherServicesSDK` pods
the native SDK links. CocoaPods builds get exactly the pinned native version;
Swift Package Manager resolves 1.22.0 or a later 1.x release.

The native SDK and Google Mobile Ads ship as static binaries, so the plugin
must link statically; its podspec declares `static_framework = true`, so this
works with the template's plain `use_frameworks!`.

Add your Google Ad Manager application ID, `NSUserTrackingUsageDescription`
and the SKAdNetwork IDs to `ios/Runner/Info.plist`; see
[Required App Setup](https://docs.ezoic.com/docs/mobileapps/ios/#required-app-setup-for-ads-to-serve).
`SKAdNetworkItems` needs every ID in Ezoic's combined list,
[docs.ezoic.com/skadnetworkids.xml](https://docs.ezoic.com/skadnetworkids.xml),
not just Google's: Apple reads these only from the app's `Info.plist`, and
buyers whose ID is missing (Amazon, InMobi, Magnite, PubMatic and other
non-Google buyers) can't use SKAdNetwork attribution.

**Android.** The native SDK is resolved from Maven Central; nothing else to add.
The plugin compiles against Google Mobile Ads 25.5.0, whose Kotlin metadata
needs Kotlin 2.2 or newer; new Flutter apps already meet this. If your
`android/settings.gradle.kts` pins `org.jetbrains.kotlin.android` to 2.1.x,
raise it to 2.2.0 or newer.

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
| `cmpEnabled` | `true` | Use the built-in CMP: the TCF 2.4 consent dialog in GDPR regions, the privacy notice and "Do Not Sell" choice in covered US states ([Privacy & Consent](#privacy--consent)) |
| `appPaid` | `null` | Whether your app is a paid app, sent to bidders as `app.paid` (`true` = 1, `false` = 0); `null` sends nothing |
| `autoPresentConsent` | `true` | After `initialize` succeeds, present the consent dialog once if it is required |

`initialize` throws a `PlatformException` if the native SDK fails to start.
It is safe to call again, including after a hot restart while the native SDK is
still initialized: repeat calls share the first call's result, and a failed call
is retried by the next one.

## Privacy & Consent

### Built-in CMP (GDPR / TCF 2.4)

The native SDK includes an IAB TCF 2.4 consent management platform. It is on by
default (`cmpEnabled: true`). In GDPR regions it shows the TCF consent dialog
described here. In covered US states it shows a privacy notice instead (see
[US-state privacy](#us-state-privacy)). Elsewhere nothing is shown and ads load
as before.

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
a decision only when the native dialog itself cannot be shown (a `Failed`
outcome): ads then carry `IABTCF_gdprApplies=1` and no TC string, which Google
treats as limited ads (and many Prebid bidders skip). Two `Failed` codes are
different: `1001` (not initialized) writes nothing, and the plugin's `-1` (no
foreground Activity / view controller) never reaches the CMP. After either,
ads stay gated and fail with 5001; call `presentConsentIfRequired()` again
once a screen is showing.

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
time, and US-state users need a way to opt out of the sale or sharing of their
information. Wire `presentConsentSettings()` to a menu item or button that is
always reachable unless `isPrivacyOptionsRequired()` is `false`:

```dart
FutureBuilder<bool?>(
  future: EzoicAds.isPrivacyOptionsRequired(),
  // null means not known yet: keep the entry point until it is false.
  builder: (context, snapshot) => snapshot.data != false
      ? TextButton(
          onPressed: EzoicAds.presentConsentSettings,
          child: const Text('Privacy choices'),
        )
      : const SizedBox.shrink(),
)
```

`isPrivacyOptionsRequired()` is `null` until the init request and the US-state
configuration have loaded, which is why the example hides the entry point only
on `false`. If the user taps it where there is nothing to show,
`presentConsentSettings()` returns `NotRequired`.

`presentConsentIfRequired()` and `presentConsentSettings()` always complete
with an `EzoicConsentOutcome`; they do not throw for consent results:

| Outcome | When |
|---|---|
| `NotRequired()` | GDPR doesn't apply, the built-in CMP is disabled (`cmpEnabled: false` or by Ezoic), another CMP owns consent, or consent is managed by the app (see [Manual consent](#manual-consent)) |
| `AlreadyDecided()` | A still-valid decision is stored; no dialog shown |
| `Decided(decision)` | The user chose `EzoicConsentDecision.acceptAll`, `rejectAll` or `custom`; the choice is saved. From the US privacy settings: `acceptAll` = not opted out, `rejectAll` = opted out |
| `Dismissed()` | The dialog closed without a choice (US privacy settings: closed without saving); in GDPR regions ads stay gated for this session. This can happen without user action (the dialog failed to start, or `resetConsent()` ran while it was loading or open) |
| `AlreadyPresenting()` | A consent dialog is already on screen, or one is being prepared with nothing on screen yet |
| `Failed(code, message)` | The dialog couldn't be shown (e.g. network error); ads proceed as limited ads (see above). `code` is the native error code (`1001` not initialized, `2001` network, `4001` render, `5002` invalid consent), or `-1` when the plugin had no foreground Activity / view controller, the platform call itself failed, or the native error had no code. Exception: after `1001` (not initialized) or `-1` nothing is written and ads stay gated (fail with 5001); call `presentConsentIfRequired()` again once a screen is showing |

- **`presentConsentSettings()`** always reopens the dialog in GDPR regions,
  even if the user already decided. In covered US states it opens the US
  privacy settings. It returns `NotRequired` elsewhere, when `cmpEnabled` is
  `false`, when another CMP is present, or when consent is managed by the app.
- **`isPrivacyOptionsRequired()`** (`Future<bool?>`) is `true` in a GDPR region
  or a covered US state while the built-in CMP is in charge, `false`
  otherwise, and `null` until the init request and the US-state configuration
  have loaded (or when the server sent no consent information).
- **`isConsentRequired()`** (`Future<bool?>`) is `null` until the init request
  completes, or when the server sent no consent information. It is `true`
  whenever GDPR applies and the built-in CMP is in charge (including after the
  user has decided) and `false` otherwise.
- **`resetConsent()`** deletes the stored decision so the dialog shows again
  (ads re-gate until the user decides). The US-state choice is forgotten too,
  and the US notice shows again at the next launch. Keys written by another
  CMP are left alone.
- Decisions are stored as standard `IABTCF_*` keys (`UserDefaults` on iOS,
  default `SharedPreferences` on Android), so Prebid, GAM and other IAB-aware
  SDKs read them as usual.

### US-state privacy

In the US states with consumer privacy laws that Ezoic's CMP covers
(California, Colorado, Connecticut, Delaware, Florida, Iowa, Montana, Nebraska,
New Hampshire, New Jersey, Oregon, Tennessee, Texas, Utah and Virginia), the
built-in CMP behaves like Ezoic's web CMP. There is nothing to call:

- **Notice.** Once per launch, until the user chooses, a "Privacy Preferences"
  card slides up from the bottom of the screen with **Consent** and **Do Not
  Sell My Information** buttons. It doesn't block the app, and an Ezoic anchor
  ad on screen is hidden while it shows. English only.
- **Choice.** **Do Not Sell My Information** opens the US privacy settings,
  where the user can opt out of the sale or sharing of their information.
  `presentConsentSettings()` opens the same screen, so your "Privacy choices"
  entry point (above) covers it.
- **Signals.** The choice is stored as the standard IAB GPP keys (`IABGPP_*`)
  for the user's state, which Prebid and other IAB-aware SDKs read. After an
  opt-out, Google Ad Manager requests ask for restricted data processing.
- **Ads never wait** for the US notice; `presentConsentIfRequired()` returns
  `NotRequired` in these states.

The SDK doesn't write GPP keys when another CMP already wrote them, when you
call `setGPPConsent`, or when `autoReadConsent` is `false`.

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
in charge until your call lands. The native SDK also writes what you pass to
the standard keys that Google Mobile Ads, IMA, Amazon and other IAB-aware SDKs
in the app read: `setGDPRConsent` writes `IABTCF_gdprApplies` and
`IABTCF_TCString`, and `setGPPConsent` writes `IABGPP_HDR_GppString` and
`IABGPP_GppSID`. Your CMP can still write the other `IABTCF_*` / `IABGPP_*`
keys (purpose and vendor consents, per-section strings) itself.

```dart
await EzoicAds.setGDPRConsent(true, 'CPXxRfAPXxRfAAfKABENB-CgAAAAAAAAAAYgAAAAAAAA');
// California (section 8, usca), not opted out.
await EzoicAds.setGPPConsent('DBABBg~BVoAAACA.QA', '8');
await EzoicAds.setSubjectToCOPPA(true);
await EzoicAds.initialize(const EzoicConfiguration(domain: 'example.com'));
```

The GPP section depends on the user's state: `8` is California (usca); other
covered states have their own section IDs (for example `9` Virginia, `10`
Colorado). Pass the section your CMP encoded, the same one it writes to
`IABGPP_GppSID`.

### Standalone CMP

[`ezoic_flutter_cmp_sdk`](ezoic_flutter_cmp_sdk/) is the same built-in CMP
without the ads SDK, for Ezoic publishers whose app doesn't show Ezoic ads. Its
`EzoicCmp` class has the consent methods above with the same names and
outcomes.

**Use one, not both.** This package already includes the CMP through
`EzoicAds`. If an app initializes both `EzoicAds` and `EzoicCmp`, `EzoicAds`
takes over the same CMP and its stored decision. If your `pubspec.yaml` must
list `ezoic_flutter_cmp_sdk` next to this package, pin it with
`dependency_overrides` to the same tag. pub otherwise reports a version
conflict, because this package already brings it in:

```yaml
dependencies:
  ezoic_flutter_sdk:
    git:
      url: https://github.com/ezoic/flutter-sdk.git
      ref: v1.22.0
dependency_overrides:
  ezoic_flutter_cmp_sdk:
    git:
      url: https://github.com/ezoic/flutter-sdk.git
      ref: v1.22.0
      path: ezoic_flutter_cmp_sdk
```

## App content for bidders

Describe your app's content to bidders with `setAppContent`. Every later ad
request carries it as OpenRTB `app.content`:

```dart
await EzoicAds.setAppContent(language: 'en', genre: 'News');
```

`language` is an ISO-639-1 two-letter code (other values are dropped with a
native warning); `genre` is free text. Leave a field out (or `null`) to omit
it; `setAppContent()` with neither clears it. It is safe to call before
`initialize`. To tell bidders whether your app is paid, set
`EzoicConfiguration.appPaid`.

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
[Privacy & Consent](#privacy--consent)). It arrives:

- as `code` on `EzoicBannerError`, `EzoicNativeAdError` and
  `EzoicOutstreamAdError` (the ad views' `onError` callbacks);
- as `code` on the `EzoicInstreamAdError` thrown by `EzoicInstreamAd.load`;
- as `PlatformException.details` when `EzoicInterstitialAd.load` or
  `EzoicRewardedAd.load` fails. (`EzoicInterstitialAdError` is only thrown by
  `show()`.)

```dart
// Ad views
onError: (error) {
  if (error.code == EzoicErrorCode.consentRequired) {
    // Ask for consent again, e.g. EzoicAds.presentConsentIfRequired().
  }
},

// Interstitial / rewarded loads
try {
  final ad = await EzoicInterstitialAd.load('12345');
  await ad.show();
} on PlatformException catch (e) {
  if (e.details == EzoicErrorCode.consentRequired) {
    // Consent is still required.
  }
}
```

## API

`EzoicAds` (all static):

- `initialize(EzoicConfiguration)` → `Future<void>`
- `setGDPRConsent(bool applies, [String? consentString])`, `setGPPConsent([String? gppString, String? sectionIds])`, `setSubjectToCOPPA(bool)` → `Future<void>`
- `trackPageview([String? screen])` → `Future<bool>`
- `setAppContent({String? language, String? genre})` → `Future<void>`
- `presentConsentIfRequired()`, `presentConsentSettings()` → `Future<EzoicConsentOutcome>`
- `isConsentRequired()`, `isPrivacyOptionsRequired()` → `Future<bool?>`
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

Banners refresh automatically every 30 seconds, or at the interval Ezoic sets
for the ad unit; you do not set a refresh timer in the app
(`refreshIntervalSeconds` and `refreshMaxCount` are deprecated and ignored). The
countdown only runs while at least half of the banner is on screen and the app
is in the foreground.

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

### Styling native ads

Pass `adStyle` to restyle the template to match your app. Every field is
optional; leave one out to keep the default (colors left out follow the system
light/dark theme). Sizes are in dp/pt. Rebuilding the widget with a different
`adStyle` re-renders the ad in place without reloading it.

```dart
SizedBox(
  height: 380,
  child: EzoicNativeAdView(
    adUnitIdentifier: '12345',
    adStyle: const EzoicNativeAdStyle(
      backgroundColor: Color(0xFF1E1E2E),
      cornerRadius: 16,
      headlineTextColor: Colors.white,
      bodyTextColor: Color(0xFFCDD6F4),
      callToActionBackgroundColor: Color(0xFF89B4FA),
      callToActionTextColor: Color(0xFF1E1E2E),
      callToActionCornerRadius: 22,
      adLabelText: 'Sponsored',
    ),
  ),
)
```

| Key | Default | Notes |
| --- | --- | --- |
| `backgroundColor` | transparent | Card background |
| `cornerRadius` | `0` | Card corners; content is clipped to them |
| `padding` | `8` | Inner padding |
| `headlineTextColor` / `headlineTextSize` | theme / `16` | Headline is bold |
| `advertiserTextColor` / `advertiserTextSize` | theme / `12` | |
| `bodyTextColor` / `bodyTextSize` | theme / `14` | |
| `callToActionBackgroundColor` / `callToActionTextColor` | platform button | |
| `callToActionTextSize` / `callToActionCornerRadius` | `14` / `4` | Radius applies when a background color is set |
| `mediaHeight` | `175` | Minimum `120`, as Google requires for native media |
| `adLabelText` | `"Ad"` | The ad attribution badge; cannot be blank |
| `adLabelTextColor` / `adLabelBackgroundColor` | `#202124` / `#FBBC04` | |

The platform view does not size itself, so give it enough height for the
template: about 330 with the defaults, plus any extra padding, larger text or a
two-line headline.

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


## Releasing

Both packages ship from one annotated `vX.Y.Z` git tag at the same version
(`ezoic_flutter_cmp_sdk` through `path:`). Consumers pin to the tag, so never
move a published tag: cut a new version instead. Release in this order:

1. **Native releases are published.** Both are needed:
   - Maven Central has `com.ezoic.sdk:ezoic-ads-sdk:X.Y.Z` and
     `com.ezoic.sdk:ezoic-cmp-sdk:X.Y.Z`.
   - [ezoic-swift-sdk-dist](https://github.com/ezoic/ezoic-swift-sdk-dist/releases)
     has the `X.Y.Z` tag with all four zips:
     `EzoicAdsSDK-X.Y.Z.xcframework.zip`,
     `EzoicAdsSDK-X.Y.Z-cocoapods.xcframework.zip`,
     `EzoicCmpSDK-X.Y.Z.xcframework.zip` and
     `EzoicCmpSDK-X.Y.Z-cocoapods.xcframework.zip`.
2. **Pin the iOS frameworks:** run `tool/pin_ios_sdk.sh X.Y.Z`. It writes the
   version and SHA-256 of both `-cocoapods` zips into both `pubspec.yaml`
   files. If the native release changed its Prebid, Google Mobile Ads or Amazon
   versions, update `ezoic.ios_sdk.pod_dependencies` in `pubspec.yaml` to match
   its `Package.swift`.
3. **Commit** the pins, together with the version bumps:
   - `version` in both `pubspec.yaml` files
   - the Maven coordinates in both `android/build.gradle.kts` files
   - `from:` in both `Package.swift` files
   - the CHANGELOGs

   Before merging, `tool/check_versions.sh --release --tag vX.Y.Z` must pass.
   The release-check workflow runs it on PRs that change a `pubspec.yaml`; you
   can also run it from the Actions tab with the version.
4. **Tag** the merged commit and push the tag:

   ```sh
   git tag -a vX.Y.Z -m "ezoic_flutter_sdk and ezoic_flutter_cmp_sdk X.Y.Z"
   git push origin vX.Y.Z
   ```

   The release-check workflow checks the tag again.
