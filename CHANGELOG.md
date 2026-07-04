## 1.4.0

* Add `EzoicOutstreamAdView` (platform-view widget rendering the native outstream video unit with load/error/impression/click/open/close callbacks).
* Add `EzoicInstreamAd` (view-less controller: `load` resolves the GAM VAST ad-tag URL, `getNextAdTagUrl` walks the floor waterfall, `reportImpression` fires the render pixel, `destroy`) wrapping the native multi-use instream video unit.
* Bump the native Ezoic Ads SDK dependency to 1.4.0 (Android `com.ezoic.sdk:ezoic-ads-sdk:1.4.0`, iOS `EzoicAdsSDK ~> 1.4`).

## 1.3.0

* Add `EzoicNativeAdView` (platform-view widget rendering an SDK-built template native ad with load/error/impression/click/open/close callbacks) wrapping the native 1.3.0 native ad units.
* Bump the native Ezoic Ads SDK dependency to 1.3.0 (Android `com.ezoic.sdk:ezoic-ads-sdk:1.3.0`, iOS `EzoicAdsSDK ~> 1.3`).

## 1.2.0

* Add `EzoicInterstitialAd` (load/show/destroy + lifecycle callbacks) wrapping the native 1.2.0 interstitial ad units.
* Bump the native Ezoic Ads SDK dependency to 1.2.0 (Android `com.ezoic.sdk:ezoic-ads-sdk:1.2.0`, iOS `EzoicAdsSDK ~> 1.2`).

## 0.0.1

* TODO: Describe initial release.
