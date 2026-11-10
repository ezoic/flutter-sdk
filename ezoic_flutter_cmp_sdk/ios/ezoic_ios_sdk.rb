# Downloads a native Ezoic XCFramework (the `-cocoapods` build) from the
# ezoic-swift-sdk-dist GitHub release, checks its SHA-256 and extracts it to
# ios/Frameworks, where the podspec vendors it from. The version and SHA-256
# are pinned in the package's pubspec.yaml under `ezoic: ios_sdk:`.
#
# Development override: EZOIC_IOS_SDK_LOCAL_DIR=<dir> takes
# <dir>/<product>-<version>-cocoapods.xcframework.zip instead of downloading.
# It skips the pinned SHA-256 and checks the zip against its `.sha256` sidecar
# when there is one.
#
# Kept byte-identical in ezoic_flutter_sdk and ezoic_flutter_cmp_sdk
# (tool/check_versions.sh); whichever podspec loads first defines it.
unless defined?(EzoicIosSdk)
  require 'digest'
  require 'fileutils'
  require 'json'
  require 'open3'
  require 'tmpdir'
  require 'yaml'

  module EzoicIosSdk
    RELEASES = 'https://github.com/ezoic/ezoic-swift-sdk-dist/releases/download'

    # Makes ios/Frameworks/<module_name>.xcframework current and returns its
    # path relative to ios_dir, for `vendored_frameworks`.
    def self.fetch(ios_dir, product, module_name)
      pubspec_path = File.join(ios_dir, '..', 'pubspec.yaml')
      pubspec = YAML.load_file(pubspec_path) || {}
      package = pubspec['name']
      pin = pubspec.dig('ezoic', 'ios_sdk') || {}
      version = pin['version'].to_s
      pinned_sha = pin['sha256'].to_s
      zip_name = "#{product}-#{version}-cocoapods.xcframework.zip"
      frameworks_dir = File.join(ios_dir, 'Frameworks')
      framework_dir = File.join(frameworks_dir, "#{module_name}.xcframework")
      stamp_file = File.join(frameworks_dir, ".#{module_name}.json")
      relative = "Frameworks/#{module_name}.xcframework"
      fail_with = lambda do |message|
        raise Pod::Informative, "#{package}: #{message}"
      end

      fail_with.call("pubspec.yaml has no ezoic.ios_sdk.version") if version.empty?

      local_dir = ENV['EZOIC_IOS_SDK_LOCAL_DIR'].to_s
      if local_dir.empty?
        unless pinned_sha.match?(/\A[0-9a-f]{64}\z/)
          fail_with.call(
            "pubspec.yaml ezoic.ios_sdk.sha256 is #{pinned_sha.inspect}, not a 64-character " \
            "hex SHA-256 of #{zip_name}. Use a released version of this package"
          )
        end
        return relative if current?(stamp_file, framework_dir, module_name, version, pinned_sha)

        url = "#{RELEASES}/#{version}/#{zip_name}"
        install(frameworks_dir, framework_dir, stamp_file, module_name, version, pinned_sha, fail_with) do |zip_path|
          Pod::UI.puts "#{package}: downloading #{url}"
          _, err, status = Open3.capture3('curl', '-fsSL', '--retry', '3', '-o', zip_path, url)
          fail_with.call("could not download #{url}: #{err.strip}") unless status.success?
        end
      else
        zip = File.join(local_dir, zip_name)
        fail_with.call("EZOIC_IOS_SDK_LOCAL_DIR has no #{zip_name}") unless File.file?(zip)
        sidecar = "#{zip}.sha256"
        expected = File.file?(sidecar) ? File.read(sidecar).split.first.to_s : Digest::SHA256.file(zip).hexdigest
        Pod::UI.warn "#{package}: using #{zip} from EZOIC_IOS_SDK_LOCAL_DIR; the pinned SHA-256 is not checked"
        return relative if current?(stamp_file, framework_dir, module_name, version, expected)

        install(frameworks_dir, framework_dir, stamp_file, module_name, version, expected, fail_with) do |zip_path|
          FileUtils.cp(zip, zip_path)
        end
      end
      relative
    end

    def self.current?(stamp_file, framework_dir, module_name, version, sha256)
      stamp = JSON.parse(File.read(stamp_file))
      stamp['version'] == version && stamp['sha256'] == sha256 && missing_slices(framework_dir, module_name).empty?
    rescue StandardError
      false
    end

    def self.missing_slices(dir, module_name)
      return ['Info.plist'] unless File.file?(File.join(dir, 'Info.plist'))

      slices = Dir.children(dir).select { |name| name.start_with?('ios-') }
      missing = []
      missing << 'ios-arm64' unless slices.include?('ios-arm64')
      missing << 'ios-*-simulator' unless slices.any? { |name| name.end_with?('-simulator') }
      slices.each do |slice|
        binary = File.join(slice, "#{module_name}.framework", module_name)
        missing << binary unless File.file?(File.join(dir, binary))
      end
      missing
    end

    # Yields a zip path to fill, verifies it, and swaps the extracted framework
    # in. Staged inside frameworks_dir so the final rename stays on one filesystem.
    def self.install(frameworks_dir, framework_dir, stamp_file, module_name, version, sha256, fail_with)
      FileUtils.mkdir_p(frameworks_dir)
      Dir.mktmpdir('.staging-', frameworks_dir) do |staging|
        zip_path = File.join(staging, 'sdk.zip')
        yield zip_path
        actual = Digest::SHA256.file(zip_path).hexdigest
        fail_with.call("SHA-256 mismatch for #{File.basename(framework_dir)}: expected #{sha256}, got #{actual}") unless actual == sha256

        out = File.join(staging, 'out')
        _, err, status = Open3.capture3('unzip', '-q', zip_path, '-d', out)
        fail_with.call("unzip failed: #{err.strip}") unless status.success?
        extracted = File.join(out, File.basename(framework_dir))
        missing = missing_slices(extracted, module_name)
        fail_with.call("unexpected archive layout, missing: #{missing.join(', ')}") unless missing.empty?

        FileUtils.rm_f(stamp_file)
        FileUtils.rm_rf(framework_dir)
        File.rename(extracted, framework_dir)
        File.write(stamp_file, JSON.pretty_generate('version' => version, 'sha256' => sha256) + "\n")
      end
    end
  end
end
