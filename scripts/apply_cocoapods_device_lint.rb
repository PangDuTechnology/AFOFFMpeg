#!/usr/bin/env ruby
# Patches the installed CocoaPods `Validator#xcodebuild` so iOS `pod spec lint` /
# `pod trunk push` use -sdk iphoneos + generic platform (not Simulator), and
# disable code signing (lint App has entitlements; device build otherwise needs a team).
# Restore: ruby scripts/restore_cocoapods_validator.rb
#
# Resolves the gem via scripts/cocoapods_device_lint_support.rb
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
  warn "  试过的 ruby 路径: #{r || '（无）'}"
  warn "可设置:  export POD_PATH=/你的/pod  再重试本脚本"
  exit 1
end

path = File.join(root, "lib", "cocoapods", "validator.rb")
unless File.file?(path)
  warn "缺少 #{path}"
  exit 1
end

original = File.read(path)
s = original.dup

a = "command += %w(CODE_SIGN_IDENTITY=- -sdk iphonesimulator)"
b = "command += Fourflusher::SimControl.new.destination(:oldest, 'iOS', deployment_target)"

# --- Phase 1: iphonesimulator -> iphoneos + generic device destination
if s.include?(a) && s.include?(b)
  if s.scan(a).length != 1 || s.scan(b).length != 1
    warn "Ambiguous simulator snippet; aborting."
    exit 1
  end
  s = s.sub(a, "command += %w(CODE_SIGN_IDENTITY=- -sdk iphoneos)")
  s = s.sub(b, "command += %w(-destination generic/platform=iOS)")
elsif s.include?("command += %w(CODE_SIGN_IDENTITY=- -sdk iphoneos)") && s.include?("generic/platform=iOS")
  # 已做过 phase1
else
  warn "在 #{path} 中未找到预期的 iOS 模拟器分支，无法打补丁："
  warn "  期望仍含: #{a}"
  warn "  或已含:   iphoneos + generic/platform=iOS"
  exit 1
end

# --- Phase 2: 真机编 lint 时关闭代码签名，避免 'App' has entitlements 要求开发证书
unless s.include?("CODE_SIGNING_ALLOWED=NO")
  s2 = s.sub(
    /(command \+= %w\(-destination generic\/platform=iOS\))(\R)([\t ]+)(xcconfig = consumer\.pod_target_xcconfig)/m,
    "\\1\\2\\3command += %w(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO)\\2\\3\\4"
  )
  if s2 == s
    warn "无法在 destination 后插入签名豁免（CocoaPods 版本可能已改行结构）。可手动在"
    warn "  Validator#xcodebuild 的 `when :ios` 中，在 generic/platform=iOS 之后增加："
    warn "  command += %w(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO)"
    exit 1
  end
  s = s2
end

if s == original
  puts "Already up to date (device SDK + no code signing for lint)."
  exit 0
end

ts = Time.now.to_i
FileUtils.cp(path, "#{path}.bak.#{ts}")
puts "Backup: #{path}.bak.#{ts}"
puts "Using gem at: #{root}"

File.write(path, s)
puts "Patched — iOS spec lint: iphoneos + generic iOS, signing disabled for lint."
exit 0
