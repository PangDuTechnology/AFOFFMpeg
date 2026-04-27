#!/usr/bin/env ruby
# Patches the installed CocoaPods `Validator#xcodebuild` so iOS `pod spec lint` /
# `pod trunk push` use -sdk iphoneos + generic platform (not Simulator).
# Restore: ruby scripts/restore_cocoapods_validator.rb
#
# If this fails to find the gem, run with the same Ruby that `pod` uses, e.g.:
#   /usr/bin/ruby scripts/apply_cocoapods_device_lint.rb
#
# Usage: ruby scripts/apply_cocoapods_device_lint.rb

require "fileutils"
require "open3"

def cocoapods_gem_root
  begin
    return Gem::Specification.find_by_name("cocoapods").full_gem_path
  rescue Gem::MissingSpecError
  end

  begin
    require "cocoapods"
    s = Gem.loaded_specs["cocoapods"]
    return s.full_gem_path if s
  rescue LoadError
  end

  [
    [ "gem", "which", "cocoapods" ],
    [ "/usr/bin/gem", "which", "cocoapods" ],
    [ "/opt/homebrew/opt/ruby/bin/gem", "which", "cocoapods" ],
    [ File.join(RbConfig::CONFIG["bindir"], "gem"), "which", "cocoapods" ],
  ].each do |cmd|
    gem_bin = cmd.first
    next if gem_bin != "gem" && !File.executable?(gem_bin)

    out, st = Open3.capture2e(*cmd)
    next unless st.success?

    p = out.strip
    next if p.empty? || !File.file?(p)

    root = File.expand_path("..", File.dirname(p))
    return root if File.file?(File.join(root, "lib", "cocoapods", "validator.rb"))
  end

  # Last resort: search Homebrew / typical gem dirs for cocoapods-*
  %w[/opt/homebrew/lib/ruby/gems /usr/local/lib/ruby/gems].each do |base|
    next unless File.directory?(base)

    Dir.glob(File.join(base, "*", "gems", "cocoapods-*")).sort_by { |d| d[/cocoapods-([0-9.]+)/, 1].to_s }.reverse_each do |d|
      v = File.join(d, "lib", "cocoapods", "validator.rb")
      return d if File.file?(v)
    end
  end

  nil
end

root = cocoapods_gem_root
unless root
  pod = `command -v pod 2>/dev/null`.strip
  warn "找不到 cocoapods gem（当前 ruby: #{RbConfig.ruby} #{RUBY_VERSION}）。"
  warn "本机 `pod` 在: #{pod.empty? ? '（未在 PATH 找到）' : pod}"
  warn "请改用与 `pod` 同一解释器执行，例如："
  warn "  /usr/bin/ruby #{File.expand_path(__FILE__)}"
  warn "或查看: head -1 \"$(command -v pod)\"  # 用里面的 ruby 跑本脚本"
  warn "或:  gem install cocoapods   # 装到当前默认 ruby"
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
