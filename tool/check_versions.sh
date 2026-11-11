#!/usr/bin/env bash
# Checks that both packages and their native pins agree.
#
#   tool/check_versions.sh            versions and native pins line up
#   tool/check_versions.sh --release  also: the iOS SHA-256 pins are real and
#                                     match the release assets, the pod pins
#                                     match ezoic-swift-sdk-dist's Package.swift
#                                     at the native tag, and the tag
#                                     (GITHUB_REF_NAME or --tag vX.Y.Z) matches
#
#   --dist-manifest <file>  compare the pod pins with a local Package.swift
#                           instead of downloading it (also without --release)
set -euo pipefail
cd "$(dirname "$0")/.."
. tool/ios_sdk_pin.sh

release=false
tag=${GITHUB_REF_NAME:-}
dist_manifest=
while [ $# -gt 0 ]; do
  case "$1" in
    --release) release=true ;;
    --tag) tag=$2; shift ;;
    --dist-manifest) dist_manifest=$2; shift ;;
    *) echo "usage: $0 [--release] [--tag vX.Y.Z] [--dist-manifest <Package.swift>]" >&2; exit 64 ;;
  esac
  shift
done

errors=0
fail() { echo "error: $*" >&2; errors=$((errors + 1)); }

version_of() { awk '$1 == "version:" { print $2; exit }' "$1"; }

ads_version=$(version_of pubspec.yaml)
cmp_version=$(version_of ezoic_flutter_cmp_sdk/pubspec.yaml)
[ "$ads_version" = "$cmp_version" ] ||
  fail "ezoic_flutter_sdk is $ads_version but ezoic_flutter_cmp_sdk is $cmp_version"

native=$(pin_get pubspec.yaml version)
[ -n "$native" ] || fail "pubspec.yaml has no ezoic.ios_sdk.version"
[ "$(pin_get ezoic_flutter_cmp_sdk/pubspec.yaml version)" = "$native" ] ||
  fail "the two ezoic.ios_sdk.version pins differ"

grep -q "\"com.ezoic.sdk:ezoic-ads-sdk:$native\"" android/build.gradle.kts ||
  fail "android/build.gradle.kts doesn't depend on ezoic-ads-sdk:$native"
grep -q "\"com.ezoic.sdk:ezoic-cmp-sdk:$native\"" ezoic_flutter_cmp_sdk/android/build.gradle.kts ||
  fail "ezoic_flutter_cmp_sdk/android/build.gradle.kts doesn't depend on ezoic-cmp-sdk:$native"
for manifest in ios/ezoic_flutter_sdk/Package.swift ezoic_flutter_cmp_sdk/ios/ezoic_flutter_cmp_sdk/Package.swift; do
  grep -q "ezoic-swift-sdk-dist.git\", from: \"$native\"" "$manifest" ||
    fail "$manifest doesn't resolve ezoic-swift-sdk-dist from $native"
done

cmp -s ios/ezoic_ios_sdk.rb ezoic_flutter_cmp_sdk/ios/ezoic_ios_sdk.rb ||
  fail "ios/ezoic_ios_sdk.rb and ezoic_flutter_cmp_sdk/ios/ezoic_ios_sdk.rb differ"

# The podspec declares the pods only from pubspec.yaml, so the pins can't fork.
for pod in "${IOS_SDK_PODS[@]}"; do
  [ -n "$(pod_get pubspec.yaml "$pod")" ] ||
    fail "pubspec.yaml ezoic.ios_sdk.pod_dependencies has no $pod"
  ! grep -qE "s\.dependency +['\"]$pod['\"]" ios/ezoic_flutter_sdk.podspec ||
    fail "ios/ezoic_flutter_sdk.podspec pins $pod itself; declare it in pubspec.yaml ezoic.ios_sdk.pod_dependencies"
done
grep -q "pod_dependencies" ios/ezoic_flutter_sdk.podspec ||
  fail "ios/ezoic_flutter_sdk.podspec doesn't read ezoic.ios_sdk.pod_dependencies"

# check_pod_pins <dist Package.swift>: the pods match what the native release
# was built against (Prebid and APS exact, Google Mobile Ads the same major).
check_pod_pins() {
  local manifest=$1 want got
  got=$(sed -nE 's#.*prebid-mobile-ios-sdk(\.git)?", exact: "([^"]+)".*#\2#p' "$manifest" | head -1)
  want=$(pod_get pubspec.yaml PrebidMobile)
  [ -n "$got" ] && [ "$got" = "$want" ] ||
    fail "PrebidMobile is '$want' in pubspec.yaml but '$got' in ezoic-swift-sdk-dist $native"
  got=$(sed -nE 's#.*swift-package-manager-amazon-aps(\.git)?", exact: "([^"]+)".*#\2#p' "$manifest" | head -1)
  want=$(pod_get pubspec.yaml AmazonPublisherServicesSDK)
  [ -n "$got" ] && [ "$got" = "$want" ] ||
    fail "AmazonPublisherServicesSDK is '$want' in pubspec.yaml but '$got' in ezoic-swift-sdk-dist $native"
  # GMA spans two lines in the manifest: the package URL, then the range.
  got=$(grep -A2 'swift-package-manager-google-mobile-ads' "$manifest" |
    sed -nE 's#.*"([0-9]+)\.[0-9]+\.[0-9]+" *\.\.<.*#\1#p' | head -1)
  want=$(pod_get pubspec.yaml Google-Mobile-Ads-SDK | sed -nE 's#^~> *([0-9]+)(\..*)?$#\1#p')
  [ -n "$got" ] && [ "$got" = "$want" ] ||
    fail "Google-Mobile-Ads-SDK major is '$want' in pubspec.yaml but '$got' in ezoic-swift-sdk-dist $native"
}

if [ -n "$dist_manifest" ]; then
  check_pod_pins "$dist_manifest"
elif $release; then
  manifest=$(mktemp)
  url=https://raw.githubusercontent.com/ezoic/ezoic-swift-sdk-dist/$native/Package.swift
  if curl -fsSL --retry 3 -o "$manifest" "$url"; then
    check_pod_pins "$manifest"
  else
    fail "could not download $url"
  fi
  rm -f "$manifest"
fi

if $release; then
  if [ -n "$tag" ] && [ "$tag" != "v$ads_version" ]; then
    fail "tag $tag doesn't match package version $ads_version"
  fi
  for entry in "${IOS_SDK_PACKAGES[@]}"; do
    read -r pubspec product <<<"$entry"
    pinned=$(pin_get "$pubspec" sha256)
    if ! [[ "$pinned" =~ ^[0-9a-f]{64}$ ]]; then
      fail "$pubspec ezoic.ios_sdk.sha256 is '$pinned'; run tool/pin_ios_sdk.sh $native"
      continue
    fi
    url=$(ios_sdk_url "$product" "$native")
    actual=$(sha256_of_url "$url") || { fail "could not download $url"; continue; }
    [ "$actual" = "$pinned" ] || fail "$url is $actual, $pubspec pins $pinned"
  done
fi

if [ "$errors" -gt 0 ]; then
  exit 1
fi
echo "ezoic_flutter_sdk and ezoic_flutter_cmp_sdk $ads_version on native $native: consistent"
