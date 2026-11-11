# Sourced by the tool/ scripts. Reads and writes the `ezoic: ios_sdk:` block
# of a pubspec.yaml (two-space indents, as committed).

# pin_get <pubspec> <version|sha256>
pin_get() {
  awk -v key="$2" '
    /^[^ #]/ { in_ezoic = ($0 ~ /^ezoic:/); in_sdk = 0 }
    in_ezoic && /^  ios_sdk:/ { in_sdk = 1; next }
    in_sdk && /^  [^ ]/ { in_sdk = 0 }
    in_sdk && $1 == key ":" { print $2; exit }
  ' "$1"
}

# pin_set <pubspec> <version|sha256> <value>
pin_set() {
  local tmp
  tmp=$(mktemp)
  awk -v key="$2" -v value="$3" '
    /^[^ #]/ { in_ezoic = ($0 ~ /^ezoic:/); in_sdk = 0 }
    in_ezoic && /^  ios_sdk:/ { in_sdk = 1; print; next }
    in_sdk && /^  [^ ]/ { in_sdk = 0 }
    in_sdk && $1 == key ":" { print "    " key ": " value; done = 1; next }
    { print }
    END { if (!done) exit 1 }
  ' "$1" > "$tmp" || { rm -f "$tmp"; echo "no ezoic.ios_sdk.$2 in $1" >&2; return 1; }
  mv "$tmp" "$1"
}

# pod_get <pubspec> <pod>: the requirement in ezoic.ios_sdk.pod_dependencies,
# without quotes.
pod_get() {
  awk -v pod="$2" '
    /^[^ #]/ { in_ezoic = ($0 ~ /^ezoic:/); in_sdk = 0; in_pods = 0 }
    in_ezoic && /^  ios_sdk:/ { in_sdk = 1; next }
    in_sdk && /^  [^ ]/ { in_sdk = 0 }
    in_sdk && /^    pod_dependencies:/ { in_pods = 1; next }
    in_pods && /^    [^ ]/ { in_pods = 0 }
    in_pods && $1 == pod ":" {
      sub(/^[^:]*:[ ]*/, ""); gsub(/"/, ""); print; exit
    }
  ' "$1"
}

# The pods the vendored ads binary links (the podspec declares them from
# pubspec.yaml), each checked against ezoic-swift-sdk-dist's Package.swift.
IOS_SDK_PODS=(PrebidMobile Google-Mobile-Ads-SDK AmazonPublisherServicesSDK)

# The packages and the release asset each one vendors.
IOS_SDK_PACKAGES=("pubspec.yaml EzoicAdsSDK" "ezoic_flutter_cmp_sdk/pubspec.yaml EzoicCmpSDK")
IOS_SDK_RELEASES=https://github.com/ezoic/ezoic-swift-sdk-dist/releases/download

# ios_sdk_url <product> <version>
ios_sdk_url() { echo "$IOS_SDK_RELEASES/$2/$1-$2-cocoapods.xcframework.zip"; }

# sha256_of_url <url>: downloads and prints the SHA-256.
sha256_of_url() {
  local tmp sum
  tmp=$(mktemp)
  curl -fsSL --retry 3 -o "$tmp" "$1" || { rm -f "$tmp"; echo "could not download $1" >&2; return 1; }
  sum=$(shasum -a 256 "$tmp" | cut -d' ' -f1)
  rm -f "$tmp"
  echo "$sum"
}
