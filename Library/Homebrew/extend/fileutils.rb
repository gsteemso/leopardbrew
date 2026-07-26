# This file is loaded before 'global.rb', so must eschew many Homebrew‐isms at eval time.
require 'fileutils'
require 'tmpdir'

# Leopardbrew extends Ruby's `File` and `FileUtils` to make our code more readable.
# @see Ruby's FileUtils API at http://docs.ruby-lang.org/

class File; class << self; alias_method :exists?, :exist? unless method_defined? :exists?; end; end

module FileUtils
  # The various File::⟨CONSTANT⟩s do not necessarily exist.  These File::O_⟨CONSTANT⟩ substitutes allow their use without having to
  # continuously test for definedness; if one isn’t implemented, it yields zero rather than nil.
  # @private
  %w[ APPEND  DIRECT  FNM_CASEFOLD  FNM_NOESCAPE  LOCK_EX  LOCK_UN  NOFOLLOW  RDONLY  SYNC
      BINARY  DSYNC   FNM_DOTMATCH  FNM_PATHNAME  LOCK_NB  NOATIME  NONBLOCK  RDWR    TRUNC
      CREAT   EXCL    FNM_EXTGLOB   FNM_SYSCASE   LOCK_SH  NOCTTY   NULL      RSYNC   WRONLY
    ].each{ |const| const_set("O_#{const}", (File::Constants.const_defined?(const) ? eval("File::#{const}") : 0).to_i) }

  FILE_BUFSIZE = 16384  # 16 KiB

  # The #copy_metadata method in all versions of Ruby before 2.0.0 has a severe bug, causing copying symlinks across filesystems to
  # fail; see Homebrew issue #14710.  This was resolved in Ruby HEAD after the release of 1.9.3p194, but was never backported.  The
  # monkey-patched method here was copied directly from the upstream fix, and then compacted into fewer lines using semicolons.
  if RUBY_VERSION < '2.0.0'
    # @private
    class Entry_
      alias_method :old_copy_metadata, :copy_metadata if RUBY_VERSION > '1.8.2'
      def copy_metadata(path)
        st = lstat
        unless st.symlink? then File.utime st.atime, st.mtime, path; end
        begin
          if st.symlink? then begin File.lchown st.uid, st.gid, path; rescue NotImplementedError; end
          else File.chown st.uid, st.gid, path; end
        rescue Errno::EPERM
          # clear setuid/setgid
          if st.symlink? then begin File.lchmod st.mode & 01777, path; rescue NotImplementedError; end
          else File.chmod st.mode & 01777, path; end
        else # no errors
          if st.symlink? then begin File.lchmod st.mode, path; rescue NotImplementedError; end
          else File.chmod st.mode, path; end
        end # begin/rescue/else block
      end # Entry_#copy_metadata()
    end # class Entry_
  end # old Ruby?

  # Run `make` 3.81 or newer.  Under stdenv uses brewed make if available, or system make from Leopard onward; under superenv, just
  # defers to the wrapper script (required for superenv argument refurbishment).  Note that when stdenv goes away permanently, this
  # method will add no functionality and may likewise be removed.
  def make(*args)
    if (mf = Formula['make']).installed? then _make = Dir["#{mf.opt_bin}/*make"].first
    elsif Utils.popen_read('/usr/bin/make', '--version').match(/Make (\d\.\d+)/)[1] > '3.80' then _make = '/usr/bin/make'
    else abort 'Your system’s Make program is too old.  Please `brew install make`.'; end
    system (superenv? ? 'make' : _make), *args
  end # make

  # @private
  alias_method :old_mkdir, :mkdir
  # A version of mkdir that also changes to that folder in a block.
  def mkdir(name, &_block); old_mkdir(name); if block_given? then chdir name do yield; end; end; end
  module_function :mkdir

  # Create a temporary directory then yield. When the block returns,
  # recursively delete the temporary directory.
  def mktemp(prefix = name)
    prev = pwd; tmp = Dir.mktmpdir(prefix, HOMEBREW_TEMP)
    begin cd(tmp); begin yield; ensure cd(prev); end
    ensure ignore_interrupts { rm_rf(tmp) }; end
  end
  module_function :mktemp

  def pathwd; Pathname(text_pwd); end

  # Run the `rake` from the `ruby` Homebrew is using rather than whatever is in the `PATH`.
  def rake(*args); system CONFIG_RUBY_BIN/'rake', *args; end

  # @private
  alias_method :old_ruby, :ruby if method_defined?(:ruby)
  # Run the `ruby` Homebrew is using rather than whatever is in the `PATH`.
  def ruby(*args); system CONFIG_RUBY_PATH, *args; end

  # Run `xcodebuild` without Homebrew's compiler environment variables set.
  def xcodebuild(*args)
    removed = ENV.remove_cc_etc; system 'xcodebuild', *args
  ensure ENV.update(removed)
  end
end # FileUtils
