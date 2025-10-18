require 'utils/json'

class AbstractDownloadStrategy
  include FileUtils

  attr_reader :meta, :name, :version, :resource

  def initialize(name, resource)
    @name = name
    @resource = resource
    @url = resource.url
    @version = resource.version
    @meta = resource.specs
  end # AbstractDownloadStrategy#initialize

  # Download and cache the resource as {#cached_location}.
  def fetch; end

  # Unpack {#cached_location} into the current working directory.
  def stage; end

  # @!attribute [r] cached_location
  # The path to the cached file or directory associated with the resource.
  def cached_location; end

  # Remove {#cached_location} and any other files associated with the resource
  # from the cache.
  def clear_cache; rm_rf(cached_location); end

  def expand_safe_system_args(args)
    args = args.dup
    args.each_with_index do |arg, ii|
      if arg.is_a? Hash
        if VERBOSE then args.delete_at ii
        else args[ii] = arg[:quiet_flag]; end
        return args
      end
    end
    # 2 as default because commands are eg. svn up, git pull
    args.insert(2, '-q') unless VERBOSE
    args
  end # AbstractDownloadStrategy#expand_safe_system_args

  def quiet_safe_system(*args); safe_system(*expand_safe_system_args(args)); end

  private

  def lhapath; OPTDIR/'lha/bin/lha'; end

  def lzippath; OPTDIR/'lzip/bin/lzip'; end

  def xzpath; OPTDIR/'xz/bin/xz'; end

  def zstdpath; OPTDIR/'zstd/bin/zstd'; end

  def cvspath
    @cvspath ||= %W[
      /usr/bin/cvs
      #{HOMEBREW_PREFIX}/bin/cvs
      #{OPTDIR}/cvs/bin/cvs
      #{which('cvs')}
    ].find{ |p| File.executable? p }
  end # AbstractDownloadStrategy#cvspath

  def hgpath
    @hgpath ||= %W[
      #{which('hg')}
      #{HOMEBREW_PREFIX}/bin/hg
      #{OPTDIR}/mercurial/bin/hg
    ].find { |p| File.executable? p }
  end # AbstractDownloadStrategy#hgpath

  def bzrpath
    @bzrpath ||= %W[
      #{which('bzr')}
      #{HOMEBREW_PREFIX}/bin/bzr
      #{OPTDIR}/bazaar/bin/bzr
    ].find { |p| File.executable? p }
  end # AbstractDownloadStrategy#bzrpath

  def fossilpath
    @fossilpath ||= %W[
      #{which('fossil')}
      #{HOMEBREW_PREFIX}/bin/fossil
      #{OPTDIR}/fossil/bin/fossil
    ].find { |p| File.executable? p }
  end # AbstractDownloadStrategy#fossilpath
end # AbstractDownloadStrategy

class VCSDownloadStrategy < AbstractDownloadStrategy
  REF_TYPES = [:tag, :branch, :revisions, :revision].freeze

  def initialize(name, resource)
    super
    @ref_type, @ref = extract_ref(meta)
    @revision = meta[:revision]
    @clone = HOMEBREW_CACHE.join(cache_filename)
  end # VCSDownloadStrategy#initialize

  def fetch
    ohai "Cloning #{@url}"
    if cached_location.exists?
      if repo_valid? then puts "Updating #{cached_location}"; update
      else puts 'Removing invalid repository from cache'; clear_cache; clone_repo; end
    else clone_repo; end
    if @ref_type == :tag and @revision and current_revision and current_revision != @revision
      raise <<-EOS.undent
        #{@ref} tag should be #{@revision},
        but is actually #{current_revision}.
      EOS
    end
  end # VCSDownloadStrategy#fetch

  def stage; ohai "Checking out #{@ref_type} #{@ref}" if @ref_type and @ref; end

  def cached_location; @clone; end

  def head?; version.head?; end

  private

  def cache_tag; '__UNKNOWN__'; end

  def cache_filename; "#{name}--#{cache_tag}"; end

  def repo_valid?; true; end

  def clone_repo; end

  def update; end

  def current_revision; end

  def extract_ref(specs); key = REF_TYPES.find { |type| specs.key?(type) }; [key, specs[key]]; end
end # VCSDownloadStrategy

class AbstractFileDownloadStrategy < AbstractDownloadStrategy
  def stage
    case cached_location.compression_type
      when :zip
        with_system_path { quiet_safe_system 'unzip', { :quiet_flag => '-qq' }, cached_location }
        chdir
      when :bzip2 then safe_system TAR_PATH, '-xjf', cached_location; chdir  # Is also tarred
      when :bzip2_only
                  then with_system_path { buffered_write('bunzip2') }
      when :compress, :tar
                  then with_system_path { safe_system TAR_PATH, '-xf', cached_location }; chdir
      when :gzip  then safe_system TAR_PATH, '-xzf', cached_location; chdir  # Is also tarred
      when :gzip_only
                  then with_system_path { buffered_write('gunzip') }
      when :lha   then safe_system lhapath, 'x', cached_location
      when :lzip  then pipe_to_tar(lzippath); chdir
      when :p7zip then safe_system '7zr', 'x', cached_location
#     when :rpm   then ???  # there is no code path to unpack these
      when :rar   then quiet_safe_system 'unrar', 'x', { :quiet_flag => '-inul' }, cached_location
      when :xar   then safe_system '/usr/bin/xar', '-xf', cached_location
      when :xz    then pipe_to_tar(xzpath); chdir
      when :zstd  then safe_system zstdpath, '-d', cached_location
      else        cp cached_location, basename_without_params
    end
  end # AbstractFileDownloadStrategy#stage

  private

  def chdir
    entries = Dir['*']
    case entries.length
    when 0 then raise 'Empty archive'
    when 1 then Dir.chdir entries.first rescue nil
    end
  end # AbstractFileDownloadStrategy#chdir

  def pipe_to_tar(tool)
    Utils.popen_read(tool, '-dc', cached_location.to_s) do |rd|
      Utils.popen_write(TAR_PATH, '-xif', '-') do |wr|
        buf = ''; wr.write(buf) while rd.read(16384, buf)
      end
    end
  end

  # gunzip and bunzip2 write the output file in the same directory as the input file regardless of
  # the current working directory, so we need to write it to the correct location ourselves.
  def buffered_write(tool)
    target = File.basename(basename_without_params, cached_location.extname)
    Utils.popen_read(tool, '-f', cached_location.to_s, '-c') do |pipe|
      File.open(target, 'wb') { |f|; buf = ''; f.write(buf) while pipe.read(16384, buf); }
    end
  end # AbstractFileDownloadStrategy#buffered_write

  # Strip any ?thing=wad out of .c?thing=wad style extensions
  def basename_without_params; File.basename(@url)[/[^?]+/]; end

  # We need a Pathname because we’ve monkeypatched extname to support double extensions (e.g.
  # tar.gz).  We can’t use basename_without_params, because given a URL pathname like
  # (.../download.php?file=foo-1.0.tar.gz), the extension we want is “.tar.gz”, not “.php”.
  def ext
    Pathname.new(@url).extname[/[^?]+/]
  end # AbstractFileDownloadStrategy#ext
end # AbstractFileDownloadStrategy

class CurlDownloadStrategy < AbstractFileDownloadStrategy
  attr_reader :mirrors, :tarball_path, :temporary_path

  def initialize(name, resource)
    super
    @mirrors = resource.mirrors.dup
    @tarball_path = HOMEBREW_CACHE/"#{name}-#{version}#{ext}"
    @temporary_path = Pathname.new("#{cached_location}.incomplete")
  end

  def fetch
    ohai "Downloading #{@url}"

    unless cached_location.exists?
      urls = actual_urls
      unless urls.empty?
        ohai "Downloading from #{urls.last}"
        if not ENV['HOMEBREW_NO_INSECURE_REDIRECT'].nil? and @url.starts_with?('https://') and
            urls.any? { |u| !u.start_with? 'https://' }
          puts 'HTTPS to HTTP redirect detected & HOMEBREW_NO_INSECURE_REDIRECT is set.'
          raise CurlDownloadStrategyError, @url
        end
        @url = urls.last
      end

      had_incomplete_download = temporary_path.exists?
      begin
        _fetch
      rescue ErrorDuringExecution
        # 33 == range not supported
        # try wiping the incomplete download and retrying once
        if $?.exitstatus == 33 and had_incomplete_download
          ohai 'Trying a full download'
          temporary_path.unlink
          had_incomplete_download = false
          retry
        else
          raise CurlDownloadStrategyError, @url
        end
      end
      ignore_interrupts { temporary_path.rename(cached_location) }
    else
      puts "Already downloaded: #{cached_location}"
    end
  rescue CurlDownloadStrategyError
    raise if mirrors.empty?
    puts 'Trying a mirror...'
    @url = mirrors.shift
    retry
  end

  def cached_location; tarball_path; end

  def clear_cache; super; rm_rf(temporary_path); end

  private

  # Private method, can be overridden if needed.
  def _fetch; curl @url, '-C', downloaded_size, '-o', temporary_path; end

  # Curl options to be always passed to curl, with raw head calls (`curl -I`) or with actual `fetch`.
  def _curl_opts; copts = []; copts << '--user' << meta.fetch(:user) if meta.key?(:user); copts; end

  def actual_urls
    urls = []
    curl_args = _curl_opts << '-I' << '-L' << @url
    Utils.popen_read('curl', *curl_args).scan(/^Location: (.+)$/).map do |m|
      urls << URI.join(urls.last || @url, m.first.chomp).to_s
    end
    urls
  end

  def downloaded_size; temporary_path.size? || 0; end

  def curl(*args); args.concat _curl_opts; args << '--connect-timeout' << '5' unless mirrors.empty?; super; end
end

# Detect and download from Apache Mirror
class CurlApacheMirrorDownloadStrategy < CurlDownloadStrategy
  def apache_mirrors
    rd, wr = IO.pipe
    buf = ''
    pid = fork do
      ENV.delete 'HOMEBREW_CURL_VERBOSE'
      rd.close
      $stdout.reopen(wr)
      $stderr.reopen(wr)
      curl "#{@url}&asjson=1"
    end
    wr.close
    rd.readline if VERBOSE  # Remove Homebrew output
    buf << rd.read until rd.eof?
    rd.close
    Process.wait(pid)
    buf
  end # CurlApacheMirrorDownloadStrategy#apache_mirrors

  def _fetch
    return super if @tried_apache_mirror
    @tried_apache_mirror = true
    mirrors = Utils::JSON.load(apache_mirrors)
    path_info = mirrors.fetch('path_info')
    @url = mirrors.fetch('preferred') + path_info
    @mirrors |= %W[https://archive.apache.org/dist/#{path_info}]
    ohai "Best Mirror #{@url}"
    super
  rescue IndexError, Utils::JSON::Error
    raise CurlDownloadStrategyError, 'Couldn’t determine mirror, try again later.'
  end # CurlApacheMirrorDownloadStrategy#_fetch
end # CurlApacheMirrorDownloadStrategy

# Download via an HTTP POST.
# Query parameters on the URL are converted into POST parameters
class CurlPostDownloadStrategy < CurlDownloadStrategy
  def _fetch
    base_url, data = @url.split('?')
    curl base_url, '-d', data, '-C', downloaded_size, '-o', temporary_path
  end
end # CurlPostDownloadStrategy

# Use this strategy to download but not unzip a file.
# Useful for installing jars.
class NoUnzipCurlDownloadStrategy < CurlDownloadStrategy
  def stage; cp cached_location, basename_without_params; end
end

# This strategy extracts our binary packages.
class CurlBottleDownloadStrategy < CurlDownloadStrategy
  def stage; ohai "Pouring #{cached_location.basename}"; super; end
end

# This strategy extracts local binary packages.
class LocalBottleDownloadStrategy < AbstractFileDownloadStrategy
  attr_reader :cached_location

  def initialize(path); @cached_location = path; end

  def stage; ohai "Pouring #{cached_location.basename}"; super; end
end # LocalBottleDownloadStrategy

# S3DownloadStrategy downloads tarballs from AWS S3.  To use it, add “:using => S3DownloadStrategy”
# to the URL section of your formula.  This download strategy uses AWS access tokens (in the
# environment variables AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY) to sign the request.  This
# strategy is good in a corporate setting, because it lets you use a private S3 bucket as a repo
# for internal distribution.  (It will work for public buckets as well.)
class S3DownloadStrategy < CurlDownloadStrategy
  def _fetch
    # Put the aws gem requirement here (vs top of file) so it’s only a dependency of S3 users, not all ’brew users.
    require 'rubygems'
    begin
      require 'aws-sdk-v1'
    rescue LoadError
      onoe 'Install the aws-sdk gem into the gem repo used by brew.'
      raise
    end
    if @url !~ %r{^https?://+([^.]+).s3.amazonaws.com/+(.+)$}
      raise RuntimeError, 'Bad S3 URL:  ' + @url
    end
    bucket = $1
    key = $2
    obj = AWS::S3.new.buckets[bucket].objects[key]
    begin
      s3url = obj.url_for(:get)
    rescue AWS::Errors::MissingCredentialsError
      ohai 'AWS credentials missing, trying public URL instead.'
      s3url = obj.public_url
    end
    curl s3url, '-C', downloaded_size, '-o', temporary_path
  end # S3DownloadStrategy#_fetch
end # S3DownloadStrategy

class SubversionDownloadStrategy < VCSDownloadStrategy
  attr_reader :svn_cmd

  def initialize(name, resource)
    super
    svnf = Formula['subversion']
    if svnf.installed? then @svn_cmd = svnf.bin/'svn'
    elsif `svn --version` =~ /version (\d+)\.(\d+)/ and $1.to_i > 1 or $1.to_i == 1 and $2.to_i > 10
      @svn_cmd = which('svn')                              # “10” is arbitrary, what should this be?
    else raise 'Your stock subversion client is obsolete.  Brew the `subversion` formula.'
    end
    @url = @url.sub('svn+http://', '')
  end # SubversionDownloadStrategy#initialize

  def fetch
    clear_cache unless @url.chomp('/') == repo_url || quiet_system(svn_cmd, 'switch', @url, cached_location)
    super
  end

  def stage; super; quiet_safe_system svn_cmd, 'export', '--force', cached_location, Dir.pwd; end

  private

  def repo_url; Utils.popen_read(svn_cmd, 'info', cached_location.to_s).strip[/^URL: (.+)$/, 1]; end

  def get_externals
    Utils.popen_read(svn_cmd, 'propget', 'svn:externals', @url).chomp.each_line do |line|
      name, url = line.split(/\s+/)
      yield name, url
    end
  end # SubversionDownloadStrategy#get_externals

  def fetch_repo(target, url, revision = nil, ignore_externals = false)
    # Use “svn up” when the repository already exists locally.  It saves on bandwidth and will have
    # a similar effect to verifying the cache as it will make any changes to get the right revision.
    svncommand = target.directory? ? 'up' : 'checkout'
    args = [svn_cmd, svncommand]
    args << url unless target.directory?
    args << target
    args << '-r' << revision if revision
    args << '--ignore-externals' if ignore_externals
    quiet_safe_system(*args)
  end # SubversionDownloadStrategy#fetch_repo

  def cache_tag; head? ? 'svn-HEAD' : 'svn'; end

  def repo_valid?; cached_location.join('.svn').directory?; end

  def clone_repo
    case @ref_type
      when :revision  then fetch_repo cached_location, @url, @ref
      when :revisions then # nil is OK for main_revision, as fetch_repo will then get latest
                           main_revision = @ref[:trunk]
                           fetch_repo cached_location, @url, main_revision, true
                           get_externals do |external_name, external_url|
                             fetch_repo cached_location+external_name, external_url, @ref[external_name], true
                           end
      else            fetch_repo cached_location, @url
    end
  end # SubversionDownloadStrategy#clone_repo
  alias_method :update, :clone_repo
end # SubversionDownloadStrategy

class GitDownloadStrategy < VCSDownloadStrategy
  SHALLOW_CLONE_WHITELIST = [
    %r{git://},
    %r{https://github\.com},
    %r{http://git\.sv\.gnu\.org},
    %r{http://llvm\.org}
  ]

  def initialize(name, resource)
    super
    @ref_type ||= :branch
    @ref ||= 'master'
    @shallow = meta.fetch(:shallow) { true }
  end # GitDownloadStrategy#initialize

  def stage; super; cp_r File.join(cached_location, '.'), Dir.pwd; end

  private

  def cache_tag; 'git'; end

  def cache_version; 0; end

  def update
    cached_location.cd do
      config_repo
      update_repo
      checkout
      reset
      update_submodules if submodules?
    end
  end # GitDownloadStrategy#update

  def shallow_clone?; @shallow && support_depth?; end

  def is_shallow_clone?; git_dir.join('shallow').exist?; end

  def support_depth?; @ref_type != :revision && SHALLOW_CLONE_WHITELIST.any? { |rx| rx === @url }; end

  def git_dir; cached_location.join('.git'); end

  def has_ref?; quiet_system 'git', '--git-dir', git_dir, 'rev-parse', '-q', '--verify', "#{@ref}^{commit}"; end

  def current_revision; Utils.popen_read('git', '--git-dir', git_dir, 'rev-parse', '-q', '--verify', 'HEAD').strip; end

  def repo_valid?; quiet_system 'git', '--git-dir', git_dir, 'status', '-s'; end

  def submodules?; cached_location.join('.gitmodules').exist?; end

  def clone_args
    args = %w[clone]
    args << '--depth' << '1' if shallow_clone?
    case @ref_type
      when :branch, :tag then args << '--branch' << @ref
    end
    args << @url << cached_location
  end # GitDownloadStrategy#clone_args

  def refspec
    case @ref_type
      when :branch then "+refs/heads/#{@ref}:refs/remotes/origin/#{@ref}"
      when :tag    then "+refs/tags/#{@ref}:refs/tags/#{@ref}"
      else              '+refs/heads/master:refs/remotes/origin/master'
    end
  end # GitDownloadStrategy#refspec

  def config_repo
    safe_system 'git', 'config', 'remote.origin.url', @url
    safe_system 'git', 'config', 'remote.origin.fetch', refspec
  end

  def update_repo
    if @ref_type == :branch || !has_ref?
      if !shallow_clone? && is_shallow_clone?
        quiet_safe_system 'git', 'fetch', 'origin', '--unshallow'
      else
        quiet_safe_system 'git', 'fetch', 'origin'
      end
    end
  end # GitDownloadStrategy#update_repo

  def clone_repo
    safe_system 'git', *clone_args
    cached_location.cd do
      safe_system 'git', 'config', 'homebrew.cacheversion', cache_version
      update_submodules if submodules?
    end
  end # GitDownloadStrategy#clone_repo

  def checkout; quiet_safe_system 'git', 'checkout', '-f', @ref, '--'; end

  def reset_args
    ref = case @ref_type
            when :branch then "origin/#{@ref}"
            when :revision, :tag then @ref
          end
    %W[reset --hard #{ref}]
  end # GitDownloadStrategy#reset_args

  def reset; quiet_safe_system 'git', *reset_args; end

  def update_submodules
    quiet_safe_system 'git', 'submodule', 'foreach', '--recursive', 'git submodule sync'
    quiet_safe_system 'git', 'submodule', 'update', '--init', '--recursive'
  end
end # GitDownloadStrategy

class CVSDownloadStrategy < VCSDownloadStrategy
  def initialize(name, resource)
    super
    @url = @url.sub(%r{^cvs://}, '')
    if meta.key?(:module) then @module = meta.fetch(:module)
    elsif @url !~ %r{:[^/]+$} then @module = name
    else @module, @url = split_url(@url)
    end
  end # CVSDownloadStrategy#initialize

  def stage; cp_r File.join(cached_location, '.'), Dir.pwd; end

  private

  def cache_tag; 'cvs'; end

  def repo_valid?; cached_location.join('CVS').directory?; end

  def clone_repo
    HOMEBREW_CACHE.cd do
      # Login is only needed (and allowed) with pserver; skip for anoncvs.
      quiet_safe_system cvspath, { :quiet_flag => '-Q' }, '-d', @url, 'login' if @url.include? 'pserver'
      quiet_safe_system cvspath, { :quiet_flag => '-Q' }, '-d', @url, 'checkout', '-d', cache_filename, @module
    end
  end # CVSDownloadStrategy#clone_repo

  def update; cached_location.cd { quiet_safe_system cvspath, { :quiet_flag => '-Q' }, 'up' }; end

  def split_url(in_url); parts = in_url.split(/:/); mod = parts.pop; url = parts.join(':'); [mod, url]; end
end # CVSDownloadStrategy

class MercurialDownloadStrategy < VCSDownloadStrategy
  def initialize(name, resource); super; @url = @url.sub(%r{^hg://}, ''); end

  def stage
    super
    dst = Dir.getwd
    cached_location.cd do
      if @ref_type and @ref then safe_system hgpath, 'archive', '--subrepos', '-y', '-r', @ref, '-t', 'files', dst
      else safe_system hgpath, 'archive', '--subrepos', '-y', '-t', 'files', dst
      end
    end
  end # MercurialDownloadStrategy#stage

  private

  def cache_tag; 'hg'; end

  def repo_valid?; cached_location.join('.hg').directory?; end

  def clone_repo; safe_system hgpath, 'clone', @url, cached_location; end

  def update; cached_location.cd { quiet_safe_system hgpath, 'pull', '--update' }; end
end # MercurialDownloadStrategy

class BazaarDownloadStrategy < VCSDownloadStrategy
  def initialize(name, resource); super; @url = @url.sub(%r{^bzr://}, ''); end

  # The export command doesn't work on checkouts; see https://bugs.launchpad.net/bzr/+bug/897511
  def stage; cp_r File.join(cached_location, '.'), Dir.pwd; rm_r '.bzr'; end

  private

  def cache_tag; 'bzr'; end

  def repo_valid?; cached_location.join('.bzr').directory?; end

  # “lightweight” means history-less
  def clone_repo; safe_system bzrpath, 'checkout', '--lightweight', @url, cached_location; end

  def update; cached_location.cd { quiet_safe_system bzrpath, 'update' }; end
end # BazaarDownloadStrategy

class FossilDownloadStrategy < VCSDownloadStrategy
  def initialize(name, resource); super; @url = @url.sub(%r{^fossil://}, ''); end

  def stage
    super
    args = [fossilpath, 'open', cached_location]
    args << @ref if @ref_type and @ref
    safe_system(*args)
  end # FossilDownloadStrategy#stage

  private

  def cache_tag; 'fossil'; end

  def clone_repo; safe_system fossilpath, 'clone', @url, cached_location; end

  def update; safe_system fossilpath, 'pull', '-R', cached_location; end
end # FossilDownloadStrategy

class DownloadStrategyDetector
  def self.detect(url, strategy = nil)
    if strategy.nil? then detect_from_url(url)
    elsif Class === strategy && strategy < AbstractDownloadStrategy then strategy
    elsif Symbol === strategy then detect_from_symbol(strategy)
    else raise TypeError, "Unknown download strategy specification #{strategy.inspect}"; end
  end # DownloadStrategyDetector⸬detect

  def self.detect_from_url(url)
    case url
      when %r{^https?://.+\.git$}, %r{^git://}
        GitDownloadStrategy
      when %r{^https?://www\.apache\.org/dyn/closer\.cgi}, %r{^https?://www\.apache\.org/dyn/closer\.lua}
        CurlApacheMirrorDownloadStrategy
      when %r{^https?://(.+?\.)?googlecode\.com/svn}, %r{^https?://svn\.}, %r{^svn://}, %r{^https?://(.+?\.)?sourceforge\.net/svnroot/}
        SubversionDownloadStrategy
      when %r{^cvs://}
        CVSDownloadStrategy
      when %r{^https?://(.+?\.)?googlecode\.com/hg}
        MercurialDownloadStrategy
      when %r{^hg://}
        MercurialDownloadStrategy
      when %r{^bzr://}
        BazaarDownloadStrategy
      when %r{^fossil://}
        FossilDownloadStrategy
      when %r{^http://svn\.apache\.org/repos/}, %r{^svn\+http://}
        SubversionDownloadStrategy
      when %r{^https?://(.+?\.)?sourceforge\.net/hgweb/}
        MercurialDownloadStrategy
      when nil
        AbstractDownloadStrategy
      else
        CurlDownloadStrategy
    end
  end # DownloadStrategyDetector⸬detect_from_url

  def self.detect_from_symbol(symbol)
    case symbol
      when :bzr     then BazaarDownloadStrategy
      when :curl    then CurlDownloadStrategy
      when :cvs     then CVSDownloadStrategy
      when :fossil  then FossilDownloadStrategy
      when :git     then GitDownloadStrategy
      when :hg      then MercurialDownloadStrategy
      when :nounzip then NoUnzipCurlDownloadStrategy
      when :post    then CurlPostDownloadStrategy
      when :ssl3    then CurlSSL3DownloadStrategy
      when :svn     then SubversionDownloadStrategy
      else          raise "Unknown download strategy #{strategy} was requested."
    end
  end # DownloadStrategyDetector⸬detect_from_symbol
end # DownloadStrategyDetector
