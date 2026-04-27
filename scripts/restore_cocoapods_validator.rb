#!/usr/bin/env ruby
# Restores validator.rb from the newest .bak, or `gem pristine`.

require "fileutils"
require "open3"
require "rbconfig"

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
  [ [ "gem", "which", "cocoapods" ], [ "/usr/bin/gem", "which", "cocoapods" ] ].each do |cmd|
    out, st = Open3.capture2e(*cmd)
    next unless st.success?
    p = out.strip
    next if p.empty? || !File.file?(p)
    root = File.expand_path("..", File.dirname(p))
    return root if File.file?(File.join(root, "lib", "cocoapods", "validator.rb"))
  end
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
  warn "找不到 cocoapods gem，见 scripts/apply_cocoapods_device_lint.rb 的说明，用与 pod 相同的 ruby 再试。"
  exit 1
end

path = File.join(root, "lib", "cocoapods", "validator.rb")
dir = File.dirname(path)
backups = Dir.glob(File.join(dir, "validator.rb.bak.*")).sort

if backups.empty?
  spec = Gem::Specification.find_by_name("cocoapods") rescue nil
  ver = spec&.version&.to_s
  ver ||= File.basename(root).sub(/\Acocoapods-/, "")
  if ver
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
