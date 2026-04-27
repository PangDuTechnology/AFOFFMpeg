#!/usr/bin/env ruby
# Restores validator.rb from the newest .bak, or `gem pristine`.

require "fileutils"
require "open3"

$LOAD_PATH << __dir__
require "cocoapods_device_lint_support"

root = CocoapodsDeviceLintSupport.cocoapods_gem_root
unless root
  warn "找不到 cocoapods gem，见 apply 脚本说明；可设 POD_PATH。"
  exit 1
end

path = File.join(root, "lib", "cocoapods", "validator.rb")
dir = File.dirname(path)
backups = Dir.glob(File.join(dir, "validator.rb.bak.*")).sort

if backups.empty?
  spec = Gem::Specification.find_by_name("cocoapods") rescue nil
  ver = spec&.version&.to_s
  ver ||= File.basename(root).sub(/\Acocoapods-/, "")
  if ver && !ver.empty?
    warn "无备份；执行: gem pristine cocoapods -v #{ver}"
    system("gem", "pristine", "cocoapods", "-v", ver) || exit($?.exitstatus || 1)
  else
    warn "无 .bak 且无法解析版本；请手动: gem pristine cocoapods"
    exit 1
  end
  puts "已用 gem pristine 恢复 cocoapods"
  exit 0
end

latest = backups.last
FileUtils.cp(latest, path)
puts "已从 #{File.basename(latest)} 恢复 #{path}"
exit 0
