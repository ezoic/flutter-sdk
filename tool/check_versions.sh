#!/usr/bin/env bash
# Checks that both packages and their native pins agree.
#
#   tool/check_versions.sh            versions and native pins line up
#   tool/check_versions.sh --release  also: the iOS SHA-256 pins are real and
#                                     match the release assets, and the tag
#                                     (GITHUB_REF_NAME or --tag vX.Y.Z) matches
set -euo pipefail
cd "$(dirname "$0")/.."
. tool/ios_sdk_pin.sh

release=false
tag=${GITHUB_REF_NAME:-}
while [ $# -gt 0 ]; do
  case "$1" in
    --release) release=true ;;
    --tag) tag=$2; shift ;;
    *) echo "usage: $0 [--release] [--tag vX.Y.Z]" >&2; exit 64 ;;
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
