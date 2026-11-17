# ezoic_flutter_sdk depends on this package, so an app that excludes the native
# CMP artifact (ezoic-cmp-sdk, README "Using your own CMP") still contains this
# plugin. Its code references these CMP classes only when the app calls
# EzoicCmp from Dart, which isn't supported in such an app (the calls fail with
# a PlatformException). Without these exact names R8 fails the release build.
-dontwarn com.ezoic.ads.sdk.privacy.cmp.CmpError
-dontwarn com.ezoic.ads.sdk.privacy.cmp.CmpLogger
-dontwarn com.ezoic.ads.sdk.privacy.cmp.EzoicCmp
-dontwarn com.ezoic.ads.sdk.privacy.cmp.EzoicCmpConfiguration
