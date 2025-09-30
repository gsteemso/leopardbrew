# This file is loaded before `global.rb`, so must eschew most Homebrew‐isms at eval time.

require 'open-uri'  # Ruby library.
# The rest are Homebrew libraries:
require 'exceptions'
require 'utils/fork'
require 'utils/git'
require 'utils/json'
require 'utils/inreplace'
require 'utils/popen'

def pretty_duration(s)
  s = s.round  # start with an integer number of seconds
  m = (s/60).truncate; _s = (s - 60*m).round  # h, m, s are totals
  h = (m/60).truncate; _m = m - 60*h          # _m, _s are < 60
  if m < 2 then "#{s.to_i} second#{plural(s)}"
  elsif h < 2 then "#{m} minute#{plural(m)} and #{_s} second#{plural(_s)}"
  else "#{h} hour#{plural(h)}, #{_m} minute#{plural(_m)}, and #{_s} second#{plural(_s)}"
  end
end # pretty_duration

def plural(n, plural = 's', singular = '', dual = nil)
  case n
    when 1 then singular
    when 2 then (dual ? dual : plural)
    else plural  # also correct for 0:  “you have no apples”
  end
end # plural

def interactive_shell(f = nil)
  unless f.nil?
    ENV['HOMEBREW_DEBUG_PREFIX'] = f.prefix
    ENV['HOMEBREW_DEBUG_INSTALL'] = f.full_name
  end
  if ENV['SHELL'].include?('zsh') && ENV['HOME'].start_with?(HOMEBREW_TEMP.resolved_path.to_s)
    FileUtils.touch "#{ENV['HOME']}/.zshrc"
  end
  Process.wait fork { exec ENV['SHELL'] }
  if $?.success? then return
  elsif $?.exited?
    puts 'Aborting due to non-zero exit status'
    exit $?.exitstatus
  else raise $?.inspect
  end
end # interactive_shell

module Homebrew
  module_function
  def _system(cmd, *args)
    pid = fork do
      yield if block_given?
      args.collect!(&:to_s)
      exec(cmd, *args) rescue nil
      exit! 1 # never gets here unless exec failed
    end
    Process.wait(pid)
    $?.success?
  end # Homebrew⸬_system

  def system(cmd, *args, &block)
    oh1 "#{cmd} #{args * ' '}".strip if VERBOSE
    _system(cmd, *args, &block)
  end

  def git_origin
    return unless Utils.git_available?
    HOMEBREW_REPOSITORY.cd { `git config --get remote.origin.url 2>/dev/null`.choke }
  end

  def git_head
    return unless Utils.git_available?
    HOMEBREW_REPOSITORY.cd { `git rev-parse --verify -q HEAD 2>/dev/null`.choke }
  end

  def git_short_head
    return unless Utils.git_available?
    HOMEBREW_REPOSITORY.cd { `git rev-parse --short=4 --verify -q HEAD 2>/dev/null`.choke }
  end

  def git_last_commit
    return unless Utils.git_available?
    HOMEBREW_REPOSITORY.cd { `git show -s --format="%cr" HEAD 2>/dev/null`.choke }
  end

  def git_last_commit_date
    return unless Utils.git_available?
    HOMEBREW_REPOSITORY.cd { `git show -s --format="%cd" --date=short HEAD 2>/dev/null`.choke }
  end

  def homebrew_version_string
    if pretty_revision = git_short_head
      last_commit = git_last_commit_date
      "#{LEOPARDBREW_VERSION} (git revision #{pretty_revision}; last commit #{last_commit})"
    else "#{LEOPARDBREW_VERSION} (no git repository)"
    end
  end # Homebrew⸬homebrew_version_string

  def install_gem_setup_path!(gem, version = nil, executable = gem)
    require 'rubygems'
    ENV.prepend_path 'PATH', CONFIG_RUBY_BIN
    ENV.prepend_path 'PATH', "#{Gem.user_dir}/bin"
    args = [gem]
    args << '-v' << version if version
    safe_system(CONFIG_RUBY_BIN/'gem', 'install', *args) \
      unless quiet_system(CONFIG_RUBY_BIN/'gem', 'list', '--installed', *args)
    odie <<-EOS.undent unless which executable
      The “#{gem}” gem is installed, but couldn’t find “#{executable}” in the PATH:
          #{ENV['PATH']}
    EOS
  end # Homebrew⸬install_gem_setup_path!
end # Homebrew

def with_system_path
  old_path = ENV['PATH']
  ENV['PATH'] = '/usr/bin:/bin'
  yield
ensure
  ENV['PATH'] = old_path
end # with_system_path

def run_as_not_developer(&_block)
  old = ENV.delete 'HOMEBREW_DEVELOPER'
  yield
ensure
  ENV['HOMEBREW_DEVELOPER'] = old
end # run_as_not_developer

# Kernel.system but with exceptions
def safe_system(cmd, *args); do_system([:safe], cmd, *args); end

# prints no output
def quiet_system(cmd, *args); do_system([:silent], cmd, *args); end
alias :silent_system :quiet_system

# Encompasses both of the above.
def do_system(flags, cmd, *args)
  (flags.include?(:silent) ? Homebrew._system(cmd, *args){
      # Redirect output streams to `/dev/null` instead of closing them – some programs will fail if
      # the stream isn’t open for writing.
      $stdout.reopen('/dev/null'); $stderr.reopen('/dev/null')
    } : Homebrew.system(cmd, *args) \
  ) or flags.include?(:safe) && raise(ErrorDuringExecution.new(cmd, args))
end # do_system

# useful for `test` blocks:

# repeats cmd for each of its runnable fat‐binary architectures
def arch_system(cmd, *args); for_archs(cmd) { |_, cmd_array| system *cmd_array, *args }; end

# Repeats {block} for each of {cmd}’s fat‐binary architectures, passing it the architecture symbol
# and an array containing the arch-qualified command string’s constituent parts.  Be aware that if
# the `arch` command can’t or shouldn’t be executed, the architecture symbol will be nil.
#   for_archs cmd do |arch, cmd_array|
#     system *cmd_array, args ...
#   end
def for_archs (cmd, &block)
  cmd = which(cmd) unless cmd.to_s =~ %r{/}
  cmd = Pathname.new(cmd) unless Pathname === cmd
  if (is_fat = cmd.fat?) and (a_tool = (which 'arch').to_s.choke)
    cmd.archs.select{ |a| CPU.can_run?(a) }.each{ |a| yield a, [a_tool, '-arch', a.to_s, cmd] }
  else
    opoo <<-_.undent if is_fat
      Can’t find the “arch” tool.  Running only the default architecture of
      #{cmd}.
    _
    yield nil, [cmd]
  end
end # for_archs

def curl(*args)
  raise "#{CURL_PATH} is not executable" unless CURL_PATH.exists? && CURL_PATH.executable?

  flags = HOMEBREW_CURL_ARGS
  flags = flags.delete('#') if VERBOSE

  args = [flags, HOMEBREW_USER_AGENT_CURL, *args]
  args << '--verbose' if ENV['HOMEBREW_CURL_VERBOSE']
  args << '--silent' unless $stdout.tty?

  safe_system CURL_PATH, *args
end # curl

def puts_columns(items, star_items = [])
  return if items.empty?

  if star_items && star_items.any?
    items = items.map { |item| star_items.include?(item) ? "#{item}*" : item }
  end

  if $stdout.tty?
    # determine the best width to display for different console sizes
    console_width = `/bin/stty size`.chomp.split(' ').last.to_i
    console_width = 80 if console_width <= 0
    max_len = items.inject(0) { |max, item| l = item.length ; l > max ? l : max }
    optimal_col_width = (console_width.to_f / (max_len + 2).to_f).floor
    cols = optimal_col_width > 1 ? optimal_col_width : 1

    IO.popen("/usr/bin/pr -#{cols} -t -w#{console_width}", 'w') { |io| io.puts(items) }
  else
    puts items
  end
end # puts_columns

def re_which(rex, path = ENV['PATH'])
  path.split(File::PATH_SEPARATOR).map{ |p| Pathname.new(p).expand_path rescue nil }.each do |pn|
    next unless pn and pn.directory?
    pn.children.each{ |cpn| if cpn.basename =~ rex then return cpn; end }
  end
end # re_which

def which(cmd, path = ENV['PATH'])
  path.split(File::PATH_SEPARATOR).each do |p|
    begin
      pcmd = File.expand_path(cmd, p)
    rescue ArgumentError
      # File.expand_path will raise an ArgumentError if the path is malformed.
      # See https://github.com/Homebrew/homebrew/issues/32789
      next
    end
    return Pathname.new(pcmd) if File.file?(pcmd) && File.executable?(pcmd)
  end
  nil
end # which

def which_for_users(cmd, path = ENV['PATH'])
  path.split(File::PATH_SEPARATOR).each do |p|
    if p.starts_with? HOMEBREW_LIBRARY.to_s then next; end
    begin
      pcmd = File.expand_path(cmd, p)
    rescue ArgumentError
      # File.expand_path will raise an ArgumentError if the path is malformed.
      # See https://github.com/Homebrew/homebrew/issues/32789
      next
    end
    return Pathname.new(pcmd) if File.file?(pcmd) && File.executable?(pcmd)
  end
  nil
end # which_for_users

def which_editor
  editor = ENV.values_at('HOMEBREW_EDITOR', 'VISUAL', 'EDITOR').compact.first
  return editor unless editor.nil?
  # Find Textmate, or BBEdit / TextWrangler, or vim, or default to standard vim
  editor = which('mate') || which('edit') || which('bbedit') || which('vim') || '/usr/bin/vim'
  opoo <<-EOS.undent
    Using #{editor} because no editor was set in the environment.
    This may change in the future, so we recommend setting EDITOR, VISUAL,
    or HOMEBREW_EDITOR to your preferred text editor.
  EOS
  editor
end # which_editor

def exec_editor(*args); safe_exec(which_editor, *args); end

def exec_browser(*args)
  browser = ENV['HOMEBREW_BROWSER'] || ENV['BROWSER'] || OPEN_PATH
  safe_exec(browser, *args)
end

# To get proper argument quoting & evaluation of environment variables in the cmd parameter.
def safe_exec(cmd, *args); exec '/bin/sh', '-c', "#{cmd} \"$@\"", '--', *args; end

# GZips the given paths, and returns the gzipped paths
def gzip(*paths)
  paths.collect do |path|
    with_system_path { safe_system 'gzip', path }
    Pathname.new("#{path}.gz")
  end
end # gzip

# Returns array of architectures that the given command or library is built for.
# Expects a bare string.  If you have a Pathname just use its #archs method.
def archs_for_command(cmd)
  cmd = which(cmd) unless cmd =~ %r{^\.?/}
  Pathname.new(cmd).archs
end

def ignore_interrupts(opt = nil)
  std_trap = trap('INT') do
    puts 'One sec, just cleaning up' unless opt == :quietly
  end
  yield
ensure
  trap('INT', std_trap)
end # ignore_interrupts

def nostdout
  if VERBOSE
    yield
  else
    begin
      out = $stdout.dup
      $stdout.reopen('/dev/null')
      yield
    ensure
      $stdout.reopen(out)
      out.close
    end
  end
end # nostdout

def paths
  @paths ||= ENV['PATH'].split(File::PATH_SEPARATOR).collect do |p|
      begin
        File.expand_path(p).chomp('/')
      rescue ArgumentError
        onoe "The following PATH component is invalid: #{p}"
      end
    end.uniq.compact
end # paths

# return the shell profile file based on users' preference shell
def shell_profile
  case ENV['SHELL']
    when %r{/bash$} then '~/.bash_profile'
    when %r{/zsh$} then '~/.zshrc'
    when %r{/ksh$} then '~/.kshrc'
    when %r{/t?csh$} then '~/.cshrc'
    when %r{/sh$} then '~/.profile'
    else '~/.login'
  end
end # shell_profile

module GitHub
  extend self

  # overrides the global one
  ISSUES_URI = URI.parse('https://api.github.com/search/issues')

  Error = Class.new(RuntimeError)
  HTTPNotFoundError = Class.new(Error)

  class AuthenticationFailedError < Error
    def initialize(error)
      super <<-EOS.undent
        GitHub #{error}
        HOMEBREW_GITHUB_API_TOKEN may be invalid or expired, check:
          https://github.com/settings/tokens
      EOS
    end # initialize
  end # AuthenticationFailedError < Error

  class RateLimitExceededError < Error
    def initialize(reset, error)
      super <<-EOS.undent
        GitHub #{error}
        Try again in #{pretty_ratelimit_reset(reset)}, or create an personal access token:
          https://github.com/settings/tokens
        and then set the token as: HOMEBREW_GITHUB_API_TOKEN
      EOS
    end # initialize

    def pretty_ratelimit_reset(reset)
      if (seconds = Time.at(reset) - Time.now) > 180
        "%d minutes %d seconds" % [seconds / 60, seconds % 60]
      else
        "#{seconds} seconds"
      end
    end # pretty_ratelimit_reset
  end # RateLimitExceeded < Error

  def open(url, &_block)
    # This is a no-op if the user is opting out of using the GitHub API.
    # Also disabled for older Ruby versions, which will either
    # not support HTTPS in open-uri or not have new enough certs.
    return if ENV['HOMEBREW_NO_GITHUB_API'] || RUBY_VERSION < '1.8.7'

    require 'net/https'

    headers = {
      'User-Agent' => HOMEBREW_USER_AGENT_RUBY,
      'Accept'     => 'application/vnd.github.v3+json'
    }

    headers['Authorization'] = "token #{HOMEBREW_GITHUB_API_TOKEN}" if HOMEBREW_GITHUB_API_TOKEN

    begin
      Kernel.open(url, headers) { |f| yield Utils::JSON.load(f.read) }
    rescue OpenURI::HTTPError => e
      handle_api_error(e)
    rescue EOFError, SocketError, OpenSSL::SSL::SSLError => e
      raise Error, "Failed to connect to: #{url}\n#{e.message}", e.backtrace
    rescue Utils::JSON::Error => e
      raise Error, "Failed to parse JSON response\n#{e.message}", e.backtrace
    end
  end # open

  def handle_api_error(e)
    if e.io.meta['x-ratelimit-remaining'].to_i <= 0
      reset = e.io.meta.fetch('x-ratelimit-reset').to_i
      error = Utils::JSON.load(e.io.read)['message']
      raise RateLimitExceededError.new(reset, error)
    end

    case e.io.status.first
      when '401', '403' then raise AuthenticationFailedError.new(e.message)
      when '404'        then raise HTTPNotFoundError, e.message, e.backtrace
      else                   raise Error, e.message, e.backtrace
    end
  end # handle_api_error

  def issues_matching(query, qualifiers = {})
    uri = ISSUES_URI.dup
    uri.query = build_query_string(query, qualifiers)
    open(uri) { |json| json['items'] }
  end

  def repository(user, repo)
    open(URI.parse("https://api.github.com/repos/#{user}/#{repo}")) { |j| j }
  end

  def build_query_string(query, qualifiers)
    s = "q=#{uri_escape(query)}+"
    s << build_search_qualifier_string(qualifiers)
    s << '&per_page=100'
  end

  def build_search_qualifier_string(qualifiers)
    {
      :repo => 'gsteemso/leopardbrew',
      :in => 'title'
    }.update(qualifiers).map do |qualifier, value|
      "#{qualifier}:#{value}"
    end.join('+')
  end # build_search_qualifier_string

  def uri_escape(query)
    if URI.responds_to?(:encode_www_form_component)
      URI.encode_www_form_component(query)
    else
      require 'erb'
      ERB::Util.url_encode(query)
    end
  end # uri_escape

  def issues_for_formula(name); issues_matching(name, :state => 'open'); end

  def print_pull_requests_matching(query)
    # Disabled on older Ruby versions - see above
    return [] if ENV['HOMEBREW_NO_GITHUB_API'] || RUBY_VERSION < '1.8.7'
    ohai 'Searching pull requests...'
    open_or_closed_prs = issues_matching(query, :type => 'pr')
    open_prs = open_or_closed_prs.select { |i| i['state'] == 'open' }
    if open_prs.any?
      puts 'Open pull requests:'
      prs = open_prs
    elsif open_or_closed_prs.any?
      puts 'Closed pull requests:'
      prs = open_or_closed_prs
    else
      return
    end
    prs.each { |i| puts "#{i['title']} (#{i['html_url']})" }
  end # print_pull_requests_matching

  def private_repo?(user, repo)
    uri = URI.parse("https://api.github.com/repos/#{user}/#{repo}")
    open(uri) { |json| json['private'] }
  end
end # GitHub
