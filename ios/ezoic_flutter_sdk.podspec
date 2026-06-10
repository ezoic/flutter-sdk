#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint ezoic_flutter_sdk.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'ezoic_flutter_sdk'
  s.version          = '1.0.0'
  s.summary          = 'Ezoic Ads SDK for Flutter (Prebid + Google Ad Manager banner ads).'
  s.description      = <<-DESC
Flutter plugin wrapping the native Ezoic Ads SDK. The iOS implementation
depends on the `EzoicAdsSDK` CocoaPods distribution and imports the binary
module as `EzoicAdsSDKBinary`.
                       DESC
  s.homepage         = 'https://github.com/ezoic/flutter-sdk'
  s.license          = { :type => 'Proprietary', :file => '../LICENSE' }
  s.author           = { 'Ezoic Inc' => 'support@ezoic.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'EzoicAdsSDK', '~> 1.0'
  s.platform = :ios, '14.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.9'
end
