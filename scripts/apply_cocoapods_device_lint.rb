#!/usr/bin/env ruby
# Patches the installed CocoaPods `Validator#xcodebuild` so iOS `pod spec lint` /
# `pod trunk push` use -sdk iphoneos + generic platform (not Simulator).
# Restore: ruby scripts/restore_cocoapods_validator.rb
#
# Resolves the gem using the same Ruby as `pod` (reads shebang from /usr/local/bin/pod etc.).
#
# Usage: ruby scripts/apply_cocoapods_device_lint.rb

require "fileutils"
require "rbconfig"

$LOAD_PATH << __dir__
require "cocoapods_device_lint_support"

root = CocoapodsDeviceLintSupport.cocoapods_gem_root
unless root
  pod = `command -v pod 2>/dev/null`.strip
  r = CocoapodsDeviceLintSupport.ruby_from_pod_shebang
  warn "找不到 cocoapods gem。"
  warn "  当前执行脚本的 ruby: #{RbConfig.ruby} (#{RUBY_VERSION})"
  warn "  `pod` 路径: #{pod.empty? ? '（无）' : pod}"
  warn "  从 pod shebang 解析到的 ruby: #{r || '（无）'}"
  warn "可设置:  export POD_PATH=/你的/pod  再重试本脚本"
  exit 1
end

path = File.join(root, "lib", "cocoapods", "validator.rb")
unless File.file?(path)
  warn "缺少 #{path}"
  exit 1
end

s = File.read(path)

a = "command += %w(CODE_SIGN_IDENTITY=- -sdk iphonesimulator)"
b = "command += Fourflusher::SimControl.new.destination(:oldest, 'iOS', deployment_target)"

if !s.include?(a) && s.include?("command += %w(-destination generic/platform=iOS)")
  puts "CocoaPods validator already uses device SDK for iOS spec lint."
  exit 0
end

unless s.include?(a) && s.include?(b)
  warn "Expected iOS simulator snippet not found in:\n  #{path}"
  warn "若 CocoaPods 大版本已改版，请手动把 `when :ios` 下两行改为 iphoneos + generic/platform=iOS"
  exit 1
end

if s.scan(a).length != 1 || s.scan(b).length != 1
  warn "Ambiguous: multiple matches; aborting."
  exit 1
end

ts = Time.now.to_i
FileUtils.cp(path, "#{path}.bak.#{ts}")
puts "Backup: #{path}.bak.#{ts}"
puts "Using gem at: #{root}"

s2 = s.sub(a, "command += %w(CODE_SIGN_IDENTITY=- -sdk iphoneos)")
s2 = s2.sub(b, "command += %w(-destination generic/platform=iOS)")

File.write(path, s2)
puts "Patched — iOS spec lint will use device SDK (not Simulator)."
exit 0
