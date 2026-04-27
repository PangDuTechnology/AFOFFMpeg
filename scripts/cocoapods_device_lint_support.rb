# frozen_string_literal: true

# Shared logic to find the cocoapods gem root, including the Ruby that /usr/local/bin/pod uses.

require "open3"
require "rbconfig"

module CocoapodsDeviceLintSupport
  module_function

  def cocoapods_gem_root
    each_candidate_ruby do |r|
      g = gem_root_from_ruby(r)
      return g if g
    end
    from_current_ruby
  end

  # 供错误提示用：从 pod 脚本解析出的 ruby 路径（可能多个，逗号拼接）
  def ruby_from_pod_shebang
    list = []
    [ ENV["POD_PATH"], `command -v pod 2>/dev/null`.strip, "/usr/local/bin/pod", "/opt/homebrew/bin/pod" ].compact.uniq.each do |pod|
      next if pod.empty? || !File.file?(pod)
      list += ruby_from_pod_shebang_line(pod) + rubies_mentioned_in_pod_script(pod)
    end
    list += homebrew_ruby_candidates
    list = list.uniq.compact
    return nil if list.empty?
    list.join(", ")
  end

  def each_candidate_ruby
    pod_candidates = [
      ENV["POD_PATH"],
      `command -v pod 2>/dev/null`.strip,
      "/usr/local/bin/pod",
      "/opt/homebrew/bin/pod"
    ]
    seen = {}
    pod_candidates.compact.uniq.each do |pod|
      next if pod.empty? || !File.file?(pod)
      next if seen[pod]
      seen[pod] = true

      rubies = ruby_from_pod_shebang_line(pod) + rubies_mentioned_in_pod_script(pod)
      rubies.uniq.compact.each { |r| yield r if r && File.executable?(r) }
    end
    homebrew_ruby_candidates.each { |r| yield r if r && File.executable?(r) }
    yield RbConfig.ruby
  end

  def homebrew_ruby_candidates
    c = []
    %w[
      /opt/homebrew/opt/ruby/bin/ruby
      /usr/local/opt/ruby/bin/ruby
    ].each { |p| c << p if File.executable?(p) }
    Dir.glob("/opt/homebrew/Cellar/ruby/*/bin/ruby").sort.reverse_each { |p| c << p }
    Dir.glob("/usr/local/Cellar/ruby/*/bin/ruby").sort.reverse_each { |p| c << p }
    # cocoapods formula often bundles ruby under libexec
    %w[
      /opt/homebrew/Cellar/cocoapods/*/libexec/bin/ruby
      /usr/local/Cellar/cocoapods/*/libexec/bin/ruby
    ].each { |g| Dir.glob(g).each { |p| c << p } }
    Dir.glob("/opt/homebrew/Cellar/cocoapods/**/libexec/**/bin/ruby").each { |p| c << p }
    Dir.glob("/usr/local/Cellar/cocoapods/**/libexec/**/bin/ruby").each { |p| c << p }
    c.uniq
  end

  def ruby_from_pod_shebang_line(pod)
    line =
      begin
        File.open(pod, &:readline)
      rescue StandardError
        return []
      end
    return [] unless line.start_with?("#!")

    sh = line[2..-1].strip
    return [] if sh.empty?

    if sh.start_with?("/usr/bin/env ")
      cmd = sh.sub(/\A\/usr\/bin\/env\s+/, "").split(/\s+/).first
      return [] if !cmd || cmd.empty?

      # env ruby 或 env bash —— 只对能解析为 ruby 的可执行文件返回
      if cmd == "ruby" || cmd.end_with?("ruby")
        resolved = `command -v ruby 2>/dev/null`.strip
        return [ resolved ] if !resolved.empty? && File.executable?(resolved) && ruby_executable?(resolved)
      end
      if %w[bash sh zsh].include?(cmd)
        return []
      end
      resolved = `command -v #{cmd} 2>/dev/null`.strip
      if !resolved.empty? && File.executable?(resolved) && ruby_executable?(resolved)
        return [ resolved ]
      end
      return []
    else
      exe = sh.split(/\s+/).first
      return [] unless exe && File.executable?(exe)
      return [] if shell_executable?(exe)
      return [ exe ] if ruby_executable?(exe)
    end
    []
  end

  def shell_executable?(path)
    %w[bash sh zsh fish dash csh ksh].include?(File.basename(path))
  end

  def ruby_executable?(path)
    return false if path.to_s.empty?
    b = File.basename(path)
    return true if b == "ruby" || b.start_with?("ruby")
    path.end_with?("/bin/ruby")
  end

  # bash 包装的 pod：从全文里找 .../bin/ruby
  def rubies_mentioned_in_pod_script(pod)
    s =
      begin
        t = File.read(pod)
        t.size > 65_535 ? t[0, 65_535] : t
      rescue StandardError
        return []
      end
    found = []
    found += s.scan(%r{((?:/[\w.+-]+)+/bin/ruby)\b}).flatten
    found += s.scan(%r{((?:/usr/local/Cellar|/opt/homebrew/Cellar)/[^'"\s\n]+/bin/ruby)}).flatten
    found += s.scan(%r{((?:/usr/local|/opt/homebrew)/[^'"\s\n]*libexec[^'"\s\n]*/bin/ruby)}).flatten
    found.uniq.compact.select { |p| File.executable?(p) }
  end

  def gem_root_from_ruby(ruby_exe)
    return nil unless ruby_exe && File.executable?(ruby_exe)

    code = <<~RUBY
      begin
        print Gem::Specification.find_by_name("cocoapods").full_gem_path
      rescue Gem::MissingSpecError
        begin
          require "cocoapods"
        rescue LoadError
        else
          print Gem.loaded_specs["cocoapods"].full_gem_path
        end
      end
    RUBY
    out, st = Open3.capture2e(ruby_exe, "-e", code)
    path = out.strip
    if st.success? && !path.empty? && File.directory?(File.join(path, "lib", "cocoapods"))
      return path
    end

    gem_exe = File.join(File.dirname(ruby_exe), "gem")
    return nil unless File.executable?(gem_exe)

    out2, st2 = Open3.capture2e(gem_exe, "which", "cocoapods")
    return nil unless st2.success?

    p = out2.strip
    return nil if p.empty? || !File.file?(p)

    root = File.expand_path("..", File.dirname(p))
    return root if File.file?(File.join(root, "lib", "cocoapods", "validator.rb"))

    nil
  end

  def from_current_ruby
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
      [ File.join(RbConfig::CONFIG["bindir"], "gem"), "which", "cocoapods" ]
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
    %w[/opt/homebrew/lib/ruby/gems /usr/local/lib/ruby/gems].each do |base|
      next unless File.directory?(base)

      Dir.glob(File.join(base, "*", "gems", "cocoapods-*")).sort_by { |d| d[/cocoapods-([0-9.]+)/, 1].to_s }.reverse_each do |d|
        v = File.join(d, "lib", "cocoapods", "validator.rb")
        return d if File.file?(v)
      end
    end
    nil
  end
end
