require "fcntl"

class FormulaLock
  LOCKDIR = HOMEBREW_FORMULA_CACHE

  def initialize(name)
    @name = name
    @path = LOCKDIR/"#{@name}.brewing"
    @lockfile = nil
  end

  def lock
    # ruby 1.8.2 doesn't implement flock
    # TODO backport the flock feature and reenable it
    return if MacOS.version == :tiger

    LOCKDIR.mkpath unless LOCKDIR.exists?
    @lockfile = get_or_create_lockfile
    unless @lockfile.flock(File::LOCK_EX | File::LOCK_NB)
      raise OperationInProgressError, @name
    end
  end # lock

  def unlock
    unless @lockfile.nil? || @lockfile.closed?
      @lockfile.flock(File::LOCK_UN)
      @lockfile.close
    end
  end # unlock

  def with_lock
    lock
    yield
  ensure
    unlock
  end # with_lock

  def delete; @path.delete if @path.file?; end

  private

  def get_or_create_lockfile
    if @lockfile.nil? || @lockfile.closed?
      @lockfile = @path.open(File::RDWR | File::CREAT)
      @lockfile.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)
      @lockfile
    else
      @lockfile
    end
  end # get_or_create_lockfile
end # FormulaLock
