# This file is loaded before 'global.rb', so must eschew many Homebrew‐isms at eval time.
require 'open3'      # Ruby libraries
require 'pathname'   #
require 'extend/fileutils'  # ’brew libraries
require 'mach'              #
require 'metafiles'         #
require 'resource'          #

# Homebrew extends Ruby's `Pathname` to make our code more readable.
# @see http://ruby-doc.org/stdlib-1.8.7/libdoc/pathname/rdoc/Pathname.html  Ruby’s Pathname API
class Pathname
  include MachO
  include FileUtils

  # @private
  BOTTLE_EXTNAME_RX = /(\.[a-z0-9_]+\.bottle\.(\d+\.)?tar\.[gl]z)$/

  alias_method :exists?, :exist? unless method_defined? :exists?
  alias_method :to_str, :to_s unless method_defined? :to_str  # we don’t wanna, but Ruby 1.8.x doesn’t care

  # https://bugs.ruby-lang.org/issues/9915
  prepend Module.new { def inspect; super.force_encoding(@path.encoding); end } if RUBY_VERSION == '2.0.0'

  def /(other); self + other.to_s; end unless method_defined?(:/)

  # @private
  def abv
    out = ''
    n = Utils.popen_read('find', expand_path.to_s, '-type', 'f', '!', '-name', '.DS_Store').split("\n").size
    out << "#{n} files, " if n > 1
    size = Utils.popen_read('/usr/bin/du', '-hs', expand_path.to_s).split("\t")[0] || '0B'
    out << size.strip; out
  end # abv

  def append(datum); dirname.mkpath; open(O_APPEND | O_CREAT | O_WRONLY) { |f| f.write(datum) }; end

  # NOTE:  Always overwrites.
  def atomic_write(content)
    require 'tempfile'
    tf = Tempfile.new(basename.to_s, dirname)
    begin
      tf.binmode; tf.write(content)
      begin
        old_stat = stat
      rescue Errno::ENOENT; old_stat = default_stat
      end
      uid = Process.uid
      gid = Process.groups.delete(old_stat.gid) { Process.gid }
      begin
        tf.chown(uid, gid); tf.chmod(old_stat.mode)
      rescue Errno::EPERM
      end
      File.rename(tf.path, self)
    ensure
      tf.close!
    end
  end # atomic_write

  # This function does not exist in Leopard stock Ruby 1.8.6.
  def binread(sz = self.size, at = 0); open(O_BINARY|O_RDONLY) { |f| f.pos = at; f.read(sz) }; end unless method_defined?(:binread)

  # This function does not exist in Leopard stock Ruby 1.8.6.
  def binwrite(datum, at = 0)
    dirname.mkpath
    open(O_BINARY|O_CREAT|O_RDWR) { |f| f.pos = at; f.write(datum) }  # Use read/write mode so seeking always works.
  end unless method_defined?(:binwrite)

  def cd; Dir.chdir(self) { yield }; end

# Pathname#chmod_R(perms) is obsolete; use FileUtils.chmod_R().

  # @private
  def compression_type
    case extname
      # If the filename ends with .bz2 or .gz not preceded by .tar, decompress but don’t untar.
      when '.bz2'         then return :bzip2_only
      when '.gz'          then return :gzip_only
      when '.jar', '.war' then return  # Don't treat jars or wars as compressed
      when '.lha', '.lzh' then return :lha
    end # case extname
    # Get enough of the file to detect common file types.  Magic numbers stolen from /usr/share/file/magic, except for the Zstd one
    # which comes from RFC 8878.  Modern tar magic has a 257 byte offset.
    case binread(262)
      when /^\x1F\x8B/n           then :gzip
      when /^\x1F\x9D/n           then :compress
      when /^\x28\xB5\x2F\xFD/n   then :zstd
      when /^7z\xBC\xAF\x27\x1C/n then :p7zip
      when /^BZh/n                then :bzip2
      when /^LZIP/n               then :lzip
      when /^PK\003\004/n         then :zip
      when /^Rar!/n               then :rar
      when /^xar!/n               then :xar
#     when /^\xED\xAB\xEE\xDB/n   then :rpm    # There is no code path to unpack these.
      when /^\xFD7zXZ\0/n         then :xz
      when /ustar$/n              then :tar
      else  # This code so that bad tarballs and archives produce good error messages when they don’t unarchive properly.
        case extname
          when %r{^\.tar(\..+)?}, '.tbz', '.tgz', '.tlz' then :tar
          when %r{^\.lz4?}    then :lzip
          when '.xz'          then :xz
          when '.Z', '.zip'   then :zip
          when '.zst'         then :zstd
        end # case extname
    end # magic number
  end # compression_type

# Pathname#cp(dst) is obsolete; use FileUtils.cp().

  # @private
  def cp_path_sub(pattern, replacement)
    raise "#{self} does not exist" unless self.exists?
    dst = sub(pattern, replacement)
    raise "#{self} is the same file as #{dst}" if self == dst
    if directory? then dst.mkpath
    else dst.dirname.mkpath
         dst = yield(self, dst) if block_given?
         cp(self, dst)
    end
  end # cp_path_sub

  def empty?; not directory? or (Dir.entries(to_s) - ['.', '..', '.DS_Store']).empty?; end

  # @private
  def ensure_writable
    saved_perms = nil; unless writable_real? then saved_perms = stat.mode; chmod 0644; end; yield
  ensure
    chmod saved_perms if saved_perms
  end

  # Writes a wrapper env script and moves all files to dst.
  def env_script_all_files(dst, env)
    dst.mkpath
    Pathname.glob("#{self}/*") do |file|
      next if file.directory?
      dst.install(file)
      new_file = dst+file.basename
      file.write_env_script(new_file, env)
    end # each child |file|
  end # env_script_all_files

  # @private
  alias_method :extname_old, :extname
  def extname(path = to_s)  # Extended to support common double extensions.
    BOTTLE_EXTNAME_RX.match(path)
    return $1 if $1
    /(\.(tar|cpio|pax)\.(gz|bz2|lz4?|xz|Z|zst))$/.match(path)
    return $1 if $1
    File.extname(path)
  end # extname

  # @private
  def incremental_hash(klass)
    digest = klass.new
    if digest.responds_to?(:file) then digest.file(self)
    else buf = ''; open('rb') { |f| digest << buf while f.read(FILE_BUFSIZE, buf) }; end
    digest.hexdigest
  end # incremental_hash

  # Moves a file from the original location to the {Pathname}’s.
  def install(*sources)
    sources.each do |src|
      case src
        when Resource          then src.stage(self)
        when Resource::Partial then src.resource.stage { install(*src.files) }
        when Array             then if src.empty? then opoo "tried to install empty array to #{self}"; return; end
                                    src.each { |s| install_p(s, File.basename(s)) }
        when Hash              then if src.empty? then opoo "tried to install empty hash to #{self}"; return; end
                                    src.each { |s, new_basename| install_p(s, new_basename) }
        else                   install_p(src, File.basename(src))
      end # case src
    end # each source |src|
  end # install

  # @private
  def install_info; quiet_system MacOS.install_info, '--quiet', to_s, "#{dirname}/dir"; end

  def install_metafiles(from = Pathname.pwd)
    Pathname(from).each_child do |p|
      next if p.directory?
      next unless Metafiles.copy?(p.basename.to_s)
      # Some software symlinks these files (see help2man.rb)
      filename = p.resolved_path
      # Some packages hardlink metafiles, so by the time we iterate to one of them we may have already moved it.  libxml2’s COPYING
      # and Copyright are an example.
      next unless filename.exists?
      filename.chmod 0644
      install(filename)
    end # each child pathname |p|
  end # install_metafiles

  # Creates symlinks to the provided targets, in this folder.
  def install_symlink(*targets)
    Array(targets).each do |tgt|
      case tgt
        when Array then tgt.each { |t| install_symlink(t) }  # Allows passing, e.g., a mixed array of filenames and hashes.
        when Hash  then tgt.each { |t, new_basename| install_symlink_p(t, new_basename) }
        else       install_symlink_p(tgt, File.basename(tgt))
      end
    end # each target |tgt|
  end # install_symlink
  alias_method :install_symlink_to, :install_symlink

  def lstat; File.lstat(self) if exists?; end

  # @private
  def make_relative_symlink(tgt); dirname.mkpath; File.symlink(tgt.relative_path_from(dirname), self); end
  alias_method :make_relative_symlink_to, :make_relative_symlink

  # @private
  def resolved_path; symlink? ? ((tgt = readlink).to_s.starts_with?('/') ? tgt : dirname/tgt) : self; end

  # @private
  def resolved_path_exists?
    return true unless symlink?; link = readlink
  rescue ArgumentError; false  # The link target contains NUL bytes.
  else (link.to_s.starts_with?('/') ? link : dirname/link).exists?
  end

  # @private
  def resolved_real_path; resolved_path.realpath; end

  # @private
  def rmdir_if_possible
    return false unless exists? and directory? and empty?
    if (ds_store = self/'.DS_Store').exists? then ds_store.unlink; end
    rmdir
  rescue Errno::EACCES; false
  end # rmdir_if_possible

  alias :old_rmtree :rmtree
  def rmtree
    if symlink?      then puts "Removing symlink #{to_s}"        if VERBOSE; unlink
    elsif directory? then puts "Removing directory tree #{to_s}" if VERBOSE; old_rmtree
    else                  puts "Removing #{to_s}"                if VERBOSE; unlink;    end
  end

  # @private
  def sha1; require 'digest/sha1'; incremental_hash(Digest::SHA1); end
  def sha256; require 'digest/sha2'; incremental_hash(Digest::SHA256); end

  # for filetypes we support, basename without extension
  def stem; File.basename((path = to_s), extname(path)); end

  # Not defined in Ruby 1.8.2.  Definition taken from 1.8.7 and then streamlined.
  def sub(pattern, *rest, &block)
    path = block_given? ? @path.sub(pattern, *rest) { |*args|
                            begin
                              old = Thread.current[:pathname_sub_matchdata]
                              Thread.current[:pathname_sub_matchdata] = $~
                              eval('$~ = Thread.current[:pathname_sub_matchdata]', block.binding)
                            ensure
                              Thread.current[:pathname_sub_matchdata] = old
                            end
                            yield(*args)
                          }
                        : @path.sub(pattern, *rest)
    self.class.new(path)
  end unless method_defined?(:sub)

  def subdirs; children.select(&:directory?); end

  # @private
  def text_executable?; /^#!\s*\S+/ === open('r') { |f| f.read(1024) }; end

  alias_method :truncate_old, :truncate
  def truncate(where); dirname.mkpath; open(O_CREAT|O_WRONLY) { |f| f.seek(where); f.write('') }; end

  # @private
  def uninstall_info; quiet_system MacOS.install_info, '--delete', '--quiet', to_s, "#{dirname}/dir"; end

  # Tiger’s ruby (1.8.2) fails to delete symlinked directories.  Pathname#unlink checks whether the target is a file or a directory,
  # & calls the appropriate File or Dir method.  However, if a target directory is really only a symlink naming one, it still calls
  # Dir.unlink, which sees the symlink as a file – & raises Errno::EISDIR.  (Is this accurate?  Even the error code is wrong?)
  if RUBY_VERSION <= '1.8.2'
    alias :oldunlink :unlink
    def unlink; symlink? ? File.unlink(to_s) : oldunlink; end
    alias :delete :unlink
  end # very old Ruby?

  # @private
  alias_method :old_write, :write if method_defined?(:write)
  def write(content, *open_args)
    raise "Will not overwrite #{to_s}" if exists?
    dirname.mkpath
    open('w', *open_args) { |f| f.write(content) }
  end

  # Writes an exec script that sets environment variables
  def write_env_script(target, env)
    env_export = ''
    env.each { |key, value| env_export += "#{key}=\"#{value}\" " }
    dirname.mkpath
    write <<-EOS.undent
      #!/bin/bash
      #{env_export}exec "#{target}" "$@"
    EOS
  end # write_env_script

  # Writes an exec script in this folder for each target pathname
  def write_exec_script(*targets)
    targets.flatten!
    if targets.empty? then opoo "tried to write exec scripts to #{to_s} for an empty list of targets"; return; end
    mkpath
    targets.each do |target|
      target = Pathname.new(target) unless target.is_a? Pathname  # allow pathnames or strings
      (self/target.basename).write <<-EOS.undent
        #!/bin/bash
        exec "#{target}" "$@"
      EOS
    end # each |target|
  end # write_exec_script

  # Writes an exec script that invokes a java jar
  def write_jar_script(target_jar, script_name, java_opts = '')
    mkpath
    (self/script_name).write <<-EOS.undent
      #!/bin/bash
      exec java #{java_opts} -jar #{target_jar} "$@"
    EOS
  end # write_jar_script

  def verify_checksum(expected)
    raise ChecksumMissingError if expected.nil? or expected.empty?
    actual = Checksum.new(expected.hash_type, send(expected.hash_type).downcase)
    raise ChecksumMismatchError.new(self, expected, actual) unless expected == actual
  end

  # @private
  def version; require 'version'; Version.parse(self); end

  private

  # We redefine these private methods in order to add the /o modifier to Regexp literals, so string interpolation happens only once
  # instead of each time the method is called. This is fixed in 1.9+.
  if RUBY_VERSION <= '1.8.7' && RUBY_VERSION > '1.8.2'
    alias_method :old_chop_basename, :chop_basename
    def chop_basename(path)
      base = File.basename(path)
      if /\A#{Pathname::SEPARATOR_PAT}?\z/o =~ base then return nil
      else return path[0, path.rindex(base)], base; end
    end

    alias_method :old_prepend_prefix, :prepend_prefix
    def prepend_prefix(prefix, relpath)
      if relpath.empty? then File.dirname(prefix)
      elsif /#{SEPARATOR_PAT}/o =~ prefix
        prefix = File.dirname(prefix)
        prefix = File.join(prefix, '') if File.basename(prefix + 'a') != 'a'
        prefix + relpath
      else prefix + relpath; end
    end # prepend_prefix
  end # old, but post‐Tiger, Ruby?

  def default_stat
    sentinel = parent.join(".brew.#{Process.pid}.#{rand(Time.now.to_i)}")
    sentinel.open('w') {}
    sentinel.stat
  ensure
    sentinel.unlink
  end # default_stat

  def install_p(src, new_basename)
    src = Pathname.new(src) unless Pathname === src
    raise Errno::ENOENT, src.to_s unless src.symlink? or src.exists?
    dst = join(new_basename)
    dst = yield(src, dst) if block_given?
    mkpath
    # Use FileUtils.mv rather than File.rename, to handle crossing filesystems.  However, if src is a symlink & its target is moved
    # first, FileUtils.mv will fail:  (https://bugs.ruby-lang.org/issues/7707).  In that case, use the system `mv` command.
    if src.symlink? then raise unless Kernel.system 'mv', src, dst; else FileUtils.mv src, dst; end
  end # install_p

  def install_symlink_p(tgt, new_basename)
    tgt = Pathname.new(tgt) unless Pathname === tgt
    tgt = tgt.expand_path(self)
    lnk = join(new_basename)
    mkpath
    ln_sf(tgt.relative_path_from(lnk.parent), lnk)
  end # install_symlink_p
end # Pathname

# @private
module ObserverPathnameExtension
  class << self
    attr_accessor :n, :d

    def counts; [n, d]; end

    def reset_counts!; @n = @d = 0; end

    def total; n + d; end
  end # << self

  def install(*sources)
    sources.each do |src|
      super(src)
      case src
        when Resource then puts "install #{self} <- #{src.name}"
        when Resource::Partial then puts "install #{self} <- #{src.files * ', '}"
        when Array then puts "install #{self} <- #{src * ', '}"
        when Hash then src.each{ |s, nm| puts "install #{parent}/#{nm} <- #{s}" }
        else puts "install #{self} <- #{src.to_s}"
      end if VERBOSE
    end # each source |src|
  end

  def install_info; super; puts "info #{self}" if VERBOSE; end

  def make_relative_symlink(tgt)
    super
    puts "ln -s #{tgt.relative_path_from(dirname)} #{basename}" if VERBOSE
    ObserverPathnameExtension.n += 1
  end
  alias_method :make_relative_symlink_to, :make_relative_symlink

  def mkdir; super; puts "mkdir #{self}" if VERBOSE; ObserverPathnameExtension.d += 1; end

  def mkpath
    dirs = []; this = self
    while not this.root? and not this.exists? do dirs << this; this = this.dirname; end
    missing_dirs = dirs.length
    super
    while not dirs.empty? do puts "mkdir #{dirs.pop}"; end if VERBOSE
    ObserverPathnameExtension.d += missing_dirs
  end

  def rmdir; super; puts "rmdir #{self}" if VERBOSE; ObserverPathnameExtension.d += 1; end

  def uninstall_info; super; puts "uninfo #{self}" if VERBOSE; end

  def unlink; super; puts "rm #{self}" if VERBOSE; ObserverPathnameExtension.n += 1; end
end # ObserverPathnameExtension
