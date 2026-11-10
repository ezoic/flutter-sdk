#
# CocoaPods spec for the Flutter plugin. Swift Package Manager builds use
# ezoic_flutter_cmp_sdk/Package.swift instead.
#
require 'yaml'
load File.join(__dir__, 'ezoic_ios_sdk.rb')

pubspec = YAML.load_file(File.join(__dir__, '..', 'pubspec.yaml'))
# Downloaded and SHA-256-checked at `pod install` (pin: pubspec.yaml ezoic.ios_sdk).
cmp_framework = EzoicIosSdk.fetch(__dir__, 'EzoicCmpSDK', 'EzoicCmpSDKBinary')

Pod::Spec.new do |s|
  s.name             = 'ezoic_flutter_cmp_sdk'
  s.version          = pubspec['version']
  s.summary          = 'Ezoic CMP for Flutter (IAB TCF in GDPR regions, US-state privacy notice and choice).'
  s.description      = <<-DESC
Flutter plugin wrapping the native Ezoic CMP. CocoaPods builds vendor
`EzoicCmpSDKBinary.xcframework` from the ezoic-swift-sdk-dist GitHub release.
This pod is the only one that vendors it: ezoic_flutter_sdk depends on it
rather than vendoring a second copy.
                       DESC
  s.homepage         = 'https://github.com/ezoic/flutter-sdk'
  s.license          = { :type => 'Proprietary', :file => '../LICENSE' }
  s.author           = { 'Ezoic Inc' => 'support@ezoic.com' }
  s.source           = { :path => '.' }
  s.source_files = 'ezoic_flutter_cmp_sdk/Sources/ezoic_flutter_cmp_sdk/**/*.swift'
  s.dependency 'Flutter'
  s.vendored_frameworks = cmp_framework
  s.platform = :ios, '15.0'
  s.static_framework = true

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.9'
end
