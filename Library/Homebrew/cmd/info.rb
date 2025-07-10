require 'blacklist'
require 'caveats'
require 'cmd/options'
require 'formula'
require 'keg'
require 'tab'
require 'utils/json'

module Homebrew
  def info
    # Eventually we’ll solidify an API, but we’ll keep old versions around awhile for compatibility.
    if ARGV.json == 'v1'
      print_json
    elsif ARGV.flag? '--github'
      exec_browser(*ARGV.formulae.map { |f| github_info(f) })
    else
      print_info
    end
  end # info

  def print_info
    if ARGV.named.empty?
      if HOMEBREW_CELLAR.exist?
        count = Formula.racks.length
        puts "#{count} keg#{plural(count)}, #{HOMEBREW_CELLAR.abv}"
      end
    else
      ARGV.named.each_with_index do |f, i|
        puts unless i == 0
        begin
          if f.include?('/') || File.exist?(f)
            info_formula Formulary.factory(f)
          else
            info_formula Formulary.find_with_priority(f)
          end
        rescue FormulaUnavailableError
          # No formula with this name, try a blacklist lookup
          if (blacklist = blacklisted?(f))
            puts blacklist
          else
            raise
          end
        end
      end
    end
  end # print_info

  def print_json
    ff = if ARGV.include? '--all'
      Formula
    elsif ARGV.include? '--installed'
      Formula.installed
    else
      ARGV.formulae
    end
    json = ff.map(&:to_hash)
    puts Utils::JSON.dump(json)
  end # print_json

  def github_remote_path(remote, path)
    if remote =~ %r{^(?:https?://|git(?:@|://))github\.com[:/](.+)/(.+?)(?:\.git)?$}
      "https://github.com/#{$1}/#{$2}/blob/master/#{path}"
    else
      "#{remote}/#{path}"
    end
  end # github_remote_path

  def github_info(f)
    if f.tap?
      user, repo = f.tap.split('/', 2)
      tap = Tap.fetch user, repo.gsub(/^homebrew-/, '')
      if remote = tap.remote
        path = f.path.relative_path_from(tap.path)
        github_remote_path(remote, path)
      else
        f.path
      end
    elsif f.core_formula?
      if remote = git_origin
        path = f.path.relative_path_from(HOMEBREW_REPOSITORY)
        github_remote_path(remote, path)
      else
        f.path
      end
    else
      f.path
    end
  end # github_info

  def info_formula(f)
    specs = []

    if stable = f.stable
      s = "stable #{stable.version}"
      s += ' (bottled)' if stable.bottled?
      specs << s
    end

    if devel = f.devel
      s = "devel #{devel.version}"
      s += ' (bottled)' if devel.bottled?
      specs << s
    end

    specs << 'HEAD' if f.head

    oh1 "#{f.full_name}:  #{specs.list}#{' (pinned)' if f.pinned?}"

    puts f.desc if f.desc

    puts f.homepage

    conflicts = f.conflicts.map(&:name).sort!
    puts "Conflicts with:  #{conflicts * ', '}" unless conflicts.empty?

    if f.rack.directory?
      kegs = f.rack.subdirs.map { |keg| Keg.new(keg) }.sort_by(&:version)
      kegs.each do |keg|
        puts "#{keg} (#{keg.abv})#{keg.linked? ? ' *' : (keg.optlinked? ? ' (*)' : '')}"
        tab = Tab.for_keg(keg).to_s
        puts tab.indent(3) unless tab.empty?
      end
    else
      puts "Not installed"
    end

    history = github_info(f)
    puts "From:  #{history}" if history

    aid_groups = f.named_enhancements
    unless f.deps.empty? and aid_groups.empty?
      ohai "Dependencies"
      %w[build required recommended optional].map do |type|
        deps = f.deps.send(type).uniq.sort
        puts "#{type.capitalize}:  #{decorate_dependencies deps}" unless deps.empty?
      end
      puts "Enhanceable by:  #{decorate_enhancement_groups(aid_groups)}" unless aid_groups.empty?
    end

    unless f.options.empty?
      ohai "Options"
      Homebrew.dump_options_for_formula f
    end

    c = Caveats.new(f)
    ohai "Caveats", c.caveats unless c.empty?
  end # info_formula

  def decorate_enhancement_groups(aid_groups)
    groups = []
    aid_groups.each do |aid_group|  # The individual groups, and lists thereof, are already sorted.
      is_grp = aid_group.length > 1
      groups << "#{'(' if is_grp}#{decorate_dependencies(aid_group, clump = true)}#{')' if is_grp}"
    end
    groups.list
  end

  def decorate_dependencies(dependencies, clump = false)
    # necessary for 1.8.7 unicode handling
    tick = ["2714".hex].pack("U*")
    cross = ["2718".hex].pack("U*")
    deps_status = dependencies.collect do |dep|
        colr = dep.installed? ? TTY.green : TTY.red
        symb = dep.installed? ? tick : cross
        colored_dep = NO_EMOJI ? "#{colr}#{dep}" : "#{dep} #{colr}#{symb}"
        "#{colored_dep}#{TTY.reset}"
      end
    clump ? deps_status * ' + ' : deps_status.list
  end # decorate_dependencies
end # Homebrew
