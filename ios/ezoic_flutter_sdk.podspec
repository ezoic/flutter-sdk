#
# CocoaPods spec for the Flutter plugin. Swift Package Manager builds use
# ezoic_flutter_sdk/Package.swift instead.
#
require 'yaml'
load File.join(__dir__, 'ezoic_ios_sdk.rb')

pubspec = YAML.load_file(File.join(__dir__, '..', 'pubspec.yaml'))
# Downloaded and SHA-256-checked at `pod install` (pin: pubspec.yaml ezoic.ios_sdk).
ads_framework = EzoicIosSdk.fetch(__dir__, 'EzoicAdsSDK', 'EzoicAdsSDKBinary')
pod_dependencies = pubspec.dig('ezoic', 'ios_sdk', 'pod_dependencies') || {}
if pod_dependencies.empty?
  raise Pod::Informative, 'ezoic_flutter_sdk: pubspec.yaml has no ezoic.ios_sdk.pod_dependencies'
end

Pod::Spec.new do |s|
  s.name             = 'ezoic_flutter_sdk'
  s.version          = pubspec['version']
  s.summary          = 'Ezoic Ads SDK for Flutter (Prebid + Google Ad Manager banner, native, interstitial and rewarded ads).'
  s.description      = <<-DESC
Flutter plugin wrapping the native Ezoic Ads SDK. CocoaPods builds vendor
`EzoicAdsSDKBinary.xcframework` (module `EzoicAdsSDKBinary`) from the
ezoic-swift-sdk-dist GitHub release; the CocoaPods trunk pod is not used.
                       DESC
  s.homepage         = 'https://github.com/ezoic/flutter-sdk'
  s.license          = { :type => 'Proprietary', :file => '../LICENSE' }
  s.author           = { 'Ezoic Inc' => 'support@ezoic.com' }
  s.source           = { :path => '.' }
  s.source_files = 'ezoic_flutter_sdk/Sources/ezoic_flutter_sdk/**/*.swift'
  s.dependency 'Flutter'
  s.vendored_frameworks = ads_framework
  # EzoicAdsSDKBinary imports the CMP framework, EzoicCmpSDKBinary. The
  # ezoic_flutter_cmp_sdk pod is the only one that vendors it, so an app that
  # also uses that package links one copy.
  s.dependency 'ezoic_flutter_cmp_sdk'

  # The pods the binary links, from pubspec.yaml ezoic.ios_sdk.pod_dependencies
  # (pod -> module: PrebidMobile -> PrebidMobile, Google-Mobile-Ads-SDK ->
  # GoogleMobileAds, AmazonPublisherServicesSDK -> DTBiOSSDK). The `-cocoapods`
  # build links the app's copies instead of embedding them, and PrebidMobile's
  # Swift ABI isn't library-evolution stable, so Prebid and APS are exact pins.
  pod_dependencies.each { |name, requirement| s.dependency name, requirement.to_s }
  s.platform = :ios, '15.0'
  s.static_framework = true

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.9'
end
