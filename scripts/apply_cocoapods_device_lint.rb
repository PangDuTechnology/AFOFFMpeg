#!/usr/bin/env ruby
# Patches the installed CocoaPods `Validator#xcodebuild` so iOS `pod spec lint` /
# `pod trunk push` use:
#   -sdk iphoneos
#   -destination generic/platform=iOS
# instead of the iOS Simulator.
#
# Restore: ruby scripts/restore_cocoapods_validator.rb
#
# Usage: ruby scripts/apply_cocoapods_device_lint.rb

require "fileutils"

begin
  spec = Gem::Specification.find_by_name("cocoapods")
rescue LoadError, Gem::MissingSpecError
  warn "Install cocoapods first: gem install cocoapods"
  exit 1
end

path = File.join(spec.full_gem_path, "lib", "cocoapods", "validator.rb")
unless File.file?(path)
  warn "Missing #{path}"
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
  warn "Edit by hand: in Validator#xcodebuild, for `when :ios` replace the two"
  warn "  lines after it with -sdk iphoneos and -destination generic/platform=iOS."
  exit 1
end

if s.scan(a).length != 1 || s.scan(b).length != 1
  warn "Ambiguous: multiple matches for the simulator lines; aborting."
  exit 1
end

ts = Time.now.to_i
FileUtils.cp(path, "#{path}.bak.#{ts}")
puts "Backup: #{path}.bak.#{ts}"

s2 = s.sub(a, "command += %w(CODE_SIGN_IDENTITY=- -sdk iphoneos)")
s2 = s2.sub(b, "command += %w(-destination generic/platform=iOS)")

File.write(path, s2)
puts "Patched — iOS spec lint will build for device SDK (not Simulator)."
exit 0
