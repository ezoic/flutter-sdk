#!/usr/bin/env bash
# Pins the vendored iOS XCFrameworks for CocoaPods builds to a released native
# version: downloads EzoicAdsSDK-<v>-cocoapods.xcframework.zip and
# EzoicCmpSDK-<v>-cocoapods.xcframework.zip from the ezoic-swift-sdk-dist
# GitHub release and writes the version and SHA-256 into each package's
# pubspec.yaml (`ezoic: ios_sdk:`). Run it once the release is published.
#
#   tool/pin_ios_sdk.sh 1.22.0
set -euo pipefail
[ $# -eq 1 ] || { echo "usage: $0 <native version>" >&2; exit 64; }
version=$1
cd "$(dirname "$0")/.."
. tool/ios_sdk_pin.sh

for entry in "${IOS_SDK_PACKAGES[@]}"; do
  read -r pubspec product <<<"$entry"
  url=$(ios_sdk_url "$product" "$version")
  sum=$(sha256_of_url "$url")
  pin_set "$pubspec" version "$version"
  pin_set "$pubspec" sha256 "$sum"
  echo "$pubspec: $product $version $sum"
done
