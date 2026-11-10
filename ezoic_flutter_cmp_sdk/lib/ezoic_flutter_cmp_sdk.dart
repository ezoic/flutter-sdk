/// Ezoic CMP for Flutter: the built-in IAB TCF consent dialog in GDPR regions
/// and the notice and "Do Not Sell" choice in covered US states, for Ezoic
/// publishers whose app doesn't use Ezoic ads.
///
/// Apps that use `ezoic_flutter_sdk` already have this CMP through `EzoicAds`;
/// use one entry point, not both.
library;

export 'src/ezoic_cmp.dart';
export 'src/ezoic_cmp_configuration.dart';
export 'src/ezoic_consent_outcome.dart';
