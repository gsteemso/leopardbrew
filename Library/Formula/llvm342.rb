class Llvm342 < Formula
  desc 'LLVM (Low Level Virtual Machine) compiler infrastructure, version 3.4.2'
  homepage 'http://llvm.org/'
  url 'http://releases.llvm.org/3.4.2/llvm-3.4.2.src.tar.gz'
  sha256 '17038d47069ad0700c063caed76f0c7259628b0e79651ce2b540d506f2f1efd7'

  resource 'clang' do
    url 'http://releases.llvm.org/3.4.2/cfe-3.4.2.src.tar.gz'
    sha256 '5ba6f5772f8d00f445209356a7daf83c5bca2da5acd10de517ad2359ae95bc10'
  end

  resource 'libcxx' do
    url 'http://releases.llvm.org/3.4.2/libcxx-3.4.2.src.tar.gz'
    sha256 '826543ee2feb5d3313b0705145255ebb2ed8d52eace878279c2525ccde6e727c'
  end

  resource 'lldb' do
    url 'http://releases.llvm.org/3.4/lldb-3.4.src.tar.gz'
    sha256 '8f74a04341cfcd8b0888e2bb3f7f5bf539691cbb81522ce6992f4209b3ac0c41'
  end

  resource 'lld' do
    url 'http://releases.llvm.org/3.4/lld-3.4.src.tar.gz'
    sha256 'bf5bd1ae551250a33c281f0d57d7aaf23561f9931440c258cdce67eb31d3a4e9'
  end

  resource 'clang-tools-extra' do
    url 'http://releases.llvm.org/3.4/clang-tools-extra-3.4.src.tar.gz'
    sha256 'ba85187551ae97fe1c8ab569903beae5ff0900e21233e5eb5389f6ceab1028b4'
  end

  resource 'test-suite' do
    url 'http://releases.llvm.org/3.4/test-suite-3.4.src.tar.gz'
    sha256 '0ff3bbb8514dd7d14b747300994fc8898c8d17e1cf071fcc25d647efef716140'
  end


  option :universal
  option 'with-lld', 'Build LLD linker'
  option 'with-lldb', 'Build LLDB debugger'

  depends_on :python if MacOS.version < :leopard  # need python 2.5 or later
                                                  # this is only used by the big test-suite package

  keg_only :provided_by_osx if MacOS.version > :leopard

  def install
    (buildpath/'projects/libcxx').install resource('libcxx')
    (buildpath/'projects/test-suite').install resource('test-suite')
    (buildpath/'tools/clang').install resource('clang')
    (buildpath/'tools/clang/tools/extra').install resource('clang-tools-extra')

    (buildpath/'tools/lld').install resource('lld') if build.with? 'lld'

    (buildpath/'tools/lldb').install resource('lldb') if build.with? 'lldb'

    mkdir 'build'
    cd 'build' do
      system '../configure', "--prefix=#{prefix}",
                             '--enable-debug-runtime',  # leave symbols in the runtime libraries
                             '--enable-jit',    # mostly useful for the `lli` tool that directly
                                                # executes LLVM bitcode
                             '--enable-optimized',  # build the release version
                             '--enable-targets=arm,powerpc,x86,x86_64'  # the useful ones on Darwin
      system 'make'
      system 'make', 'check-all'                # runs quick built-in tests (not the big test suite)
      system 'make', 'install'
    end

    system 'make', '-C', 'runtime', 'install-bytecode', "DSTROOT=#{prefix}"
    system 'make', '-C', 'projects/libcxx', 'install', "DSTROOT=#{prefix}",
                                                       "SYMROOT=#{buildpath}/projects/libcxx"

    (share/'clang/tools').install Dir['tools/clang/tools/scan-{build,view}']
    inreplace "#{share}/clang/tools/scan-build/scan-build", '$RealBin/bin/clang', "#{bin}/clang"
    bin.install_symlink share/'clang/tools/scan-build/scan-build', share/'clang/tools/scan-view/scan-view'
    man1.install_symlink share/'clang/tools/scan-build/scan-build.1'
  end

  def caveats
    <<-EOS.undent
      LLVM executables are installed in #{opt_bin}.
      Extra tools are installed in #{opt_share}/llvm.
    EOS
  end

  test do
    system "#{bin}/llvm-config", '--version'
  end
end
