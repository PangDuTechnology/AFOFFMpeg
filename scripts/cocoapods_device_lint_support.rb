# frozen_string_literal: true

# Shared logic to find the cocoapods gem root, including the Ruby that /usr/local/bin/pod uses.

require "open3"
require "rbconfig"

module CocoapodsDeviceLintSupport
  module_function

  def pod_shim_paths
    [ ENV["POD_PATH"], `command -v pod 2>/dev/null`.strip, "/usr/local/bin/pod", "/opt/homebrew/bin/pod" ]
      .compact
      .uniq
      .select { |p| p && !p.empty? && File.file?(p) }
  end

  # Homebrew: /usr/local/bin/pod 第一行是 bash，用 GEM_HOME=.../libexec 指向已打包的 gem 树
  def gem_root_from_brew_pod_wrapper
    pod_shim_paths.each do |pod|
      s = begin
        File.read(pod, 12_288)
      rescue StandardError
        next
      end
      gem_home = nil
      m = s.match(/GEM_HOME=["']([^"']+)["']/) || s.match(/GEM_HOME=([^\s\n]+)/)
      if m
        gem_home = m[1]
      elsif (m2 = s.match(/exec\s+["']([^"']+)["']/))
        # e.g. exec ".../Cellar/cocoapods/1.16.2_1/libexec/bin/pod"
        pod_path = m2[1]
        if pod_path.end_with?("/libexec/bin/pod")
          gem_home = File.dirname(File.dirname(pod_path))
        end
      end
      next unless gem_home && File.directory?(gem_home)
      r = find_cocoapods_gem_under_gem_home(gem_home)
      return r if r
    end
    nil
  end

  def find_cocoapods_gem_under_gem_home(gem_home)
    Dir.glob(File.join(gem_home, "gems", "cocoapods-*")).sort.reverse_each do |d|
      v = File.join(d, "lib", "cocoapods", "validator.rb")
      return d if File.file?(v)
    end
    nil
  end

  def cocoapods_gem_root
    g = gem_root_from_brew_pod_wrapper
    return g if g

    each_candidate_ruby do |r|
      g2 = gem_root_from_ruby(r)
      return g2 if g2
    end
    from_current_ruby
  end

  # 供错误提示
  def gem_home_from_pod_shim
    pod_shim_paths.each do |pod|
      s = File.read(pod, 12_288) rescue next
      m = s.match(/GEM_HOME=["']([^"']+)["']/) || s.match(/GEM_HOME=([^\s\n]+)/)
      return m[1] if m
      m2 = s.match(/exec\s+["']([^"']+)["']/)
      if m2 && m2[1].end_with?("/libexec/bin/pod")
        return File.dirname(File.dirname(m2[1]))
      end
    end
    nil
  end

  # 供错误提示用：从 pod 解析出的 ruby / Homebrew 等路径
  def ruby_from_pod_shebang
    list = []
    pod_shim_paths.each do |pod|
      list += ruby_from_pod_shebang_line(pod) + rubies_mentioned_in_pod_script(pod)
    end
    list += homebrew_ruby_candidates
    list = list.uniq.compact
    g = gem_home_from_pod_shim
    list.unshift("GEM_HOME=#{g}") if g
    return nil if list.empty?
    list.join(", ")
  end

  def each_candidate_ruby
    seen = {}
    pod_shim_paths.each do |pod|
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
