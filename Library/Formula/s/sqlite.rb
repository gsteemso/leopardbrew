# stable release 2025-07-30; checked 2025-08-08
class Sqlite < Formula
  desc 'Command-line interface for SQLite'
  homepage 'https://sqlite.org/'
  url 'https://sqlite.org/2025/sqlite-autoconf-3500400.tar.gz'
  version '3.50.4'
  sha256 'a3db587a1b92ee5ddac2f66b3edb41b26f9c867275782d46c3a088977d6a5b18'

  keg_only :provided_by_osx, 'OS X provides an older sqlite3.'

  option :universal
  option 'with-secure-delete', 'Defaults secure_delete to on'
  option 'with-unlock-notify', 'Enable the unlock notification feature'

  enhanced_by 'readline'

  resource 'docs' do
    url 'https://sqlite.org/2025/sqlite-doc-3500400.zip'
    version '3.50.4'
    sha256 'f8a03cf461500310c7a785c9d6f86121ac9465601982cdcac6de0c5987dbfc2f'
  end

  def install
    # Sqlite segfaults on Tiger/PPC with our gcc-4.2.
    ENV.no_optimization if CPU.powerpc? and ENV.compiler == :gcc and MacOS.version == :tiger

    # (The recommended set of optimizations.)

    # Disable the “double-quoted string literal” misfeature:
    ENV.append 'CPPFLAGS', '-DSQLITE_DQS=0'
    # Disable memory‐usage tracking (for speed):
    ENV.append 'CPPFLAGS', '-DSQLITE_DEFAULT_MEMSTATUS=0'
    # Set a better synchronization default for Write‐Ahead Log (WAL) mode:
    ENV.append 'CPPFLAGS', '-DSQLITE_DEFAULT_WAL_SYNCHRONOUS=1'
    # Stop LIKE and GLOB operations from matching BLOBs (for speed):
    ENV.append 'CPPFLAGS', '-DSQLITE_LIKE_DOESNT_MATCH_BLOBS'
    # Disable expression‐depth checking (for speed and memory usage):
    ENV.append 'CPPFLAGS', '-DSQLITE_MAX_EXPR_DEPTH=0'
    # (Do not disable deprecated features and interfaces, because Python uses at least one of them.)
    # (Do not disable the progress‐handler callback feature [for speed], because Python uses it.)
    # (Do not disable the shared cache [for speed], because Python uses it.)
    # Use the “alloca” on‐stack memory allocator where applicable (for speed):
    ENV.append 'CPPFLAGS', '-DSQLITE_USE_ALLOCA'
    # (Do not disable autoinitialization [for speed], for reliability.)
    # Enforce the requirements of the sqlite3_result_subtype() interface (for reliability):
    ENV.append 'CPPFLAGS', '-DSQLITE_STRICT_SUBTYPE=1'

    # (Optimizations that this formula has added in the past.)

    # The default value of MAX_VARIABLE_NUMBER is now 32766.  If this is too low for your
    # application, file a Leopardbrew bug report and we will raise it; in the meantime, we do not
    # intend to second‐guess the SQLite developers.

    # (Optimizations that this recipe previously made optional.)

    # Enable the various column-metadata interfaces:
    ENV.append 'CPPFLAGS', '-DSQLITE_ENABLE_COLUMN_METADATA'
    # Enable the DBSTAT virtual table:
    ENV.append 'CPPFLAGS', '-DSQLITE_ENABLE_DBSTAT_VTAB'
    # Enable versions 3 through 5 of the Full‐Text Search feature:
    ENV.append 'CPPFLAGS', '-DSQLITE_ENABLE_FTS3 -DSQLITE_ENABLE_FTS3_PARENTHESIS -DSQLITE_ENABLE_FTS5'
    # JSON serialization is now enabled by default.
    # Enable the R*Tree index extension:
    ENV.append 'CPPFLAGS', '-DSQLITE_ENABLE_RTREE=1'
    # Enable the session extension and the preüpdate hooks that enhance it:
    ENV.append 'CPPFLAGS', '-DSQLITE_ENABLE_SESSION -DSQLITE_ENABLE_PREUPDATE_HOOK'

    # (Still‐optional optimizations.)

    # Cause deletion to involve overwriting with zeroes:
    ENV.append 'CPPFLAGS', '-DSQLITE_SECURE_DELETE=1' if build.with? 'secure-delete'
    # Enable the unlock‐notify API:
    ENV.append 'CPPFLAGS', '-DSQLITE_ENABLE_UNLOCK_NOTIFY=1' if build.with? 'unlock-notify'

    ENV.universal_binary if build.universal?

    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-static-shell',
                          '--disable-readline', '--editline'
    system 'make'
    # There is no `make check`.
    system 'make', 'install'

    doc.install resource('docs')
  end

  test do
    path = testpath/'school.sql'
    path.write <<-EOS.undent
      create table students (name text, age integer);
      insert into students (name, age) values ('Bob', 14);
      insert into students (name, age) values ('Sue', 12);
      insert into students (name, age) values ('Tim', 13);
      select name from students order by age asc;
    EOS

    names = shell_output("#{bin}/sqlite3 < #{path}").strip.split("\n")
    assert_equal %w[Sue Tim Bob], names
  end
end
