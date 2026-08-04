require 'metafiles'
require 'formula'

module Homebrew
  def list
    # Use of exec means we don’t explicitly exit.
    list_unbrewed if ARGV.flag? '--unbrewed'
    # Unbrewed uses the PREFIX, which exists.  Things below use the CELLAR, which might not until the first formula is installed.
    unless HOMEBREW_CELLAR.exists?
      raise NoSuchRackError, ARGV.named.first if ARGV.named.any?
      return
    end
    if ARGV.intersects? %w[--pinned --versions] then filtered_list
    elsif ARGV.named.empty?
      if ARGV.includes? '--full-name'
        puts_columns Formula.installed.map(&:full_name).sort{ |a, b|
          if        a.includes?('/') and not b.includes?('/') then  1  # Sort core formulæ before tapped ones.
          elsif not a.includes?('/') and     b.includes?('/') then -1  #
          else a <=> b; end
        }
      else exec 'ls', *(ARGV.options_only - ARGV.flags_only), HOMEBREW_CELLAR  # need to exclude --flags, because they choke `ls`
      end
    elsif VERBOSE or not $stdout.tty? then exec 'find', *ARGV.kegs.map(&:to_s) + %w[-not -type d -print]
    else ARGV.kegs.each { |keg| PrettyListing.new keg }; end
  end # Homebrew#list

  private

  UNBREWED_EXCLUDE_FILES = %w[.DS_Store]
  UNBREWED_EXCLUDE_PATHS = %w[ bin/brew
    lib/gdk-pixbuf-2.0/*  lib/gio/*      lib/node_modules/*    lib/python[23].{,1}[0-9]/*  lib/pypy/*             lib/pypy3/*
    share/pypy/*          share/pypy3/*  share/doc/homebrew/*  share/info/dir              share/man/man1/brew.1  share/man/whatis
  ]

  def list_unbrewed
    dirs  = HOMEBREW_PREFIX.subdirs.map{ |dir| dir.basename.to_s }
    dirs -= %w[.git Cellar Library]

    # Exclude the repository and cache, if they are located under the prefix
    dirs.delete HOMEBREW_CACHE.relative_path_from(HOMEBREW_PREFIX).to_s
    dirs.delete HOMEBREW_REPOSITORY.relative_path_from(HOMEBREW_PREFIX).to_s
    dirs.delete 'etc'
    dirs.delete 'var'

    args = dirs + ['-type' 'f' '(']
    args.concat UNBREWED_EXCLUDE_FILES.flat_map{ |f| %W[! -name #{f}] }
    args.concat UNBREWED_EXCLUDE_PATHS.flat_map{ |d| %W[! -path #{d}] }
    args << ')'

    cd HOMEBREW_PREFIX
    exec 'find', *args
  end # Homebrew#list_unbrewed

  def filtered_list
    names = (ARGV.named.empty? ? Formula.racks : ARGV.named.map{ |n| HOMEBREW_CELLAR/n }.select(&:exists?))
    if ARGV.includes? '--pinned'
      pinned_versions = {}
      names.each{ |d|
        keg_pin = (PINDIR/d.basename.to_s)
        pinned_versions[d] = keg_pin.readlink.basename.to_s if keg_pin.exists? or keg_pin.symlink?
      }
      puts_columns pinned_versions.map{ |d, version| "#{d.basename}#{" #{version}" if ARGV.includes?('--versions')}" }
    else  # --versions without --pinned
      puts_columns names.map{ |d|
        versions = d.subdirs.map{ |pn| pn.basename.to_s }
        next if ARGV.includes?('--multiple') and versions.length < 2
        "#{d.basename} #{versions * ' '}"
      }
    end # “--pinned”?
  end # Homebrew#filtered_list
end # Homebrew

class PrettyListing
  def initialize(path)
    Pathname(path).children.sort_by{ |p| p.to_s.downcase }.each{ |pn|
      case pn.basename.to_s
        when 'bin', 'sbin' then pn.find { |pnn| puts pnn unless pnn.directory? }
        when 'lib'         then  # Dylibs have multiple symlinks we don’t care about.
                                print_dir pn { |pnn| (pnn.extname == '.dylib' || pnn.extname == '.pc') and not pnn.symlink? }
        else if pn.directory? then if pn.symlink? then puts "#{pn} -> #{pn.readlink}" else print_dir pn; end
             elsif Metafiles.list?(pn.basename.to_s) then puts pn; end
      end # case
    } # each |pn|
  end # PrettyListing#initialize()

  def print_dir(root)
    dirs = []; remaining_root_files = []; other = ''
    root.children.sort.each{ |pn|
      if pn.directory? then dirs << pn
      elsif block_given? and yield(pn) then puts pn; other = 'other '
      else remaining_root_files << pn unless pn.basename.to_s == '.DS_Store'; end
    }
    dirs.each{ |d|
      files = []
      d.find { |pn| files << pn unless pn.directory? }
      print_remaining_files files, d
    }
    print_remaining_files remaining_root_files, root, other
  end # PrettyListing#print_dir()

  def print_remaining_files(files, root, other = '')
    case files.length
      when 0 then ;  # no‐op
      when 1 then puts files
             else puts "#{root}/ (#{files.length} #{other}files)"
    end
  end # PrettyListing#print_remaining_files()
end # PrettyListing
