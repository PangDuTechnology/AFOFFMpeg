#!/usr/bin/env ruby
# Restores validator.rb from the newest .bak next to the file, or `gem pristine`.
#
# Usage: ruby scripts/restore_cocoapods_validator.rb

require "fileutils"

begin
  spec = Gem::Specification.find_by_name("cocoapods")
rescue LoadError, Gem::MissingSpecError
  warn "Install cocoapods first."
  exit 1
end

path = File.join(spec.full_gem_path, "lib", "cocoapods", "validator.rb")
dir = File.dirname(path)
backups = Dir.glob(File.join(dir, "validator.rb.bak.*")).sort

if backups.empty?
  version = spec.version
  warn "No validator.rb.bak.* found; trying: gem pristine cocoapods -v #{version}"
  system("gem", "pristine", "cocoapods", "-v", version.to_s) || exit($?.exitstatus || 1)
  puts "Restored cocoapods via gem pristine."
  exit 0
end

latest = backups.last
FileUtils.cp(latest, path)
puts "Restored #{path} from #{File.basename(latest)}"
exit 0
