#!/usr/bin/env bash
# Creates a throwaway Flutter app that depends on this repo's packages by path,
# for build checks in CI and locally.
#
#   tool/create_test_app.sh <ads|cmp|both> <dir> [--spm|--cocoapods]
#
#   ads   ezoic_flutter_sdk (which brings ezoic_flutter_cmp_sdk with it)
#   cmp   ezoic_flutter_cmp_sdk alone
#   both  both packages declared by the app
#
# The iOS package manager is set in the app's pubspec (default --spm), so the
# machine's `flutter config` is left alone.
set -euo pipefail

usage() { echo "usage: $0 <ads|cmp|both> <dir> [--spm|--cocoapods]" >&2; exit 64; }
[ $# -ge 2 ] || usage
case_name=$1
dir=$2
pm=${3:---spm}
case "$case_name" in ads|cmp|both) ;; *) usage ;; esac
case "$pm" in --spm) spm=true ;; --cocoapods) spm=false ;; *) usage ;; esac

repo=$(cd "$(dirname "$0")/.." && pwd)
[ ! -e "$dir" ] || { echo "$dir already exists" >&2; exit 1; }

flutter create --platforms=android,ios --org com.ezoic.ci \
  --project-name "ezoic_${case_name}_app" "$dir"
cd "$dir"

deps=()
case "$case_name" in
  ads) deps=("ezoic_flutter_sdk:{path: $repo}") ;;
  cmp) deps=("ezoic_flutter_cmp_sdk:{path: $repo/ezoic_flutter_cmp_sdk}") ;;
  both) deps=("ezoic_flutter_sdk:{path: $repo}" "ezoic_flutter_cmp_sdk:{path: $repo/ezoic_flutter_cmp_sdk}") ;;
esac
flutter pub add "${deps[@]}"

cat >> pubspec.yaml <<YAML
  config:
    enable-swift-package-manager: $spm
YAML

# The plugins need iOS 15; new Flutter apps default to 13.0.
sed -i.bak 's/IPHONEOS_DEPLOYMENT_TARGET = 1[0-4]\.0;/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/' \
  ios/Runner.xcodeproj/project.pbxproj
rm ios/Runner.xcodeproj/project.pbxproj.bak

ads_import="import 'package:ezoic_flutter_sdk/ezoic_flutter_sdk.dart';"
cmp_import="import 'package:ezoic_flutter_cmp_sdk/ezoic_flutter_cmp_sdk.dart';"
case "$case_name" in
  ads) imports=$ads_import ;;
  cmp) imports=$cmp_import ;;
  both) imports="$ads_import
$cmp_import" ;;
esac

ads_init="  await EzoicAds.setAppContent(language: 'en', genre: 'News');
  await EzoicAds.initialize(
      const EzoicConfiguration(domain: 'example.com', appPaid: false));"
cmp_init="  await EzoicCmp.initialize('example.com');"
case "$case_name" in
  ads) init=$ads_init; entry=EzoicAds ;;
  cmp) init=$cmp_init; entry=EzoicCmp ;;
  both) init="$cmp_init
$ads_init"; entry=EzoicAds ;;
esac

banner=""
[ "$case_name" = cmp ] || banner="            const EzoicBannerView(adUnitIdentifier: '12345'),"

cat > lib/main.dart <<DART
import 'package:flutter/material.dart';
$imports

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Home()));
$init
}

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder<bool?>(
              future: $entry.isPrivacyOptionsRequired(),
              builder: (context, snapshot) =>
                  Text('privacy options required: \${snapshot.data}'),
            ),
            TextButton(
              onPressed: () async =>
                  debugPrint('\${await $entry.presentConsentSettings()}'),
              child: const Text('Privacy settings'),
            ),
$banner
          ],
        ),
      ),
    );
  }
}
DART
echo "Created $case_name app in $dir (iOS Swift Package Manager: $spm)"
