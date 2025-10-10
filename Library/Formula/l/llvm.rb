class Llvm < Formula
  desc "llvm (Low Level Virtual Machine): a next-gen compiler infrastructure"
  homepage "http://llvm.org/"

  stable do
    url "http://llvm.org/releases/3.6.2/llvm-3.6.2.src.tar.xz"
    sha256 "f60dc158bfda6822de167e87275848969f0558b3134892ff54fced87e4667b94"

    resource "clang" do
      url "http://llvm.org/releases/3.6.2/cfe-3.6.2.src.tar.xz"
      sha256 "ae9180466a23acb426d12444d866b266ff2289b266064d362462e44f8d4699f3"
    end

    resource "libcxx" do
      url "http://llvm.org/releases/3.6.2/libcxx-3.6.2.src.tar.xz"
      sha256 "52f3d452f48209c9df1792158fdbd7f3e98ed9bca8ebb51fcd524f67437c8b81"
    end

    resource "lld" do
      url "http://llvm.org/releases/3.6.2/lld-3.6.2.src.tar.xz"
      sha256 "43f553c115563600577764262f1f2fac3740f0c639750f81e125963c90030b33"
    end

    resource "lldb" do
      url "http://llvm.org/releases/3.6.2/lldb-3.6.2.src.tar.xz"
      sha256 "940dc96b64919b7dbf32c37e0e1d1fc88cc18e1d4b3acf1e7dfe5a46eb6523a9"
    end

    resource "clang-tools-extra" do
      url "http://llvm.org/releases/3.6.2/clang-tools-extra-3.6.2.src.tar.xz"
      sha256 "6a0ec627d398f501ddf347060f7a2ccea4802b2494f1d4fd7bda3e0442d04feb"
    end
  end

  bottle do
    cellar :any
    sha256 "fa04afc62800a236e32880efe30e1dbb61eace1e7e9ec20d2d53393ef9d68636" => :el_capitan
    sha256 "a0ec4b17ae8c1c61071e603d0dcf3e1c39a5aae63c3f8237b4363a06701a3319" => :yosemite
    sha256 "17a62c19d119c88972fa3dce920cfbc6150af8892ba8e29ce551ae7e2e84f42e" => :mavericks
    sha256 "6d780faae2647ebce704b2f0a246b52d4037ebf4a2f796644814607e7751af93" => :mountain_lion
  end

  head do
    url "http://llvm.org/git/llvm.git"

    resource "clang" do
      url "http://llvm.org/git/clang.git"
    end

    resource "libcxx" do
      url "http://llvm.org/git/libcxx.git"
    end

    resource "lld" do
      url "http://llvm.org/git/lld.git"
    end

    resource "lldb" do
      url "http://llvm.org/git/lldb.git"
    end

    resource "clang-tools-extra" do
      url "http://llvm.org/git/clang-tools-extra.git"
    end
  end

  option :universal
  option "with-clang", "Build Clang support library"
  option "with-lld", "Build LLD linker"
  option "with-lldb", "Build LLDB debugger"
  option "with-python", "Build Python bindings against Homebrew Python" unless MacOS.version <= :snow_leopard
  option "with-rtti", "Build with C++ RTTI"
  option "without-assertions", "Speeds up LLVM, but provides less debug information"

  deprecated_option "rtti" => "with-rtti"
  deprecated_option "disable-assertions" => "without-assertions"

  needs :cxx11

  if MacOS.version <= :snow_leopard
    depends_on :python
  else
    depends_on :python => :optional
  end
  depends_on "cmake" => :build

  depends_on "swig" if build.with? "lldb"

  keg_only :provided_by_osx if MacOS.version > :leopard

  # Apple's libstdc++ is too old to build LLVM
  fails_with :gcc
  fails_with :llvm

  def install
    args = %w[
      -DLLVM_OPTIMIZED_TABLEGEN=On
    ]

    # Apple's libstdc++ is too old to build LLVM
    ENV.libcxx if ENV.compiler == :clang
    if build.universal?
      ENV.permit_arch_flags
      args << "-DCMAKE_OSX_ARCHITECTURES=#{Target.local_archs.as_cmake_arch_flags}"
    end

    if build.with? "lldb"
      raise "Building LLDB needs Clang support library." if build.without?("clang")
      (buildpath/"tools/lldb").install resource("lldb")
      args << '-DLLDB_USE_SYSTEM_DEBUGSERVER=ON'
    end

    if build.with? "clang"
      (buildpath/"projects/libcxx").install resource("libcxx")
      (buildpath/"tools/clang").install resource("clang")
      (buildpath/"tools/clang/tools/extra").install resource("clang-tools-extra")
    end

    (buildpath/"tools/lld").install resource("lld") if build.with? "lld"

    args << "-DLLVM_ENABLE_RTTI=On" if build.with? "rtti"

    if build.with? "assertions"
      args << "-DLLVM_ENABLE_ASSERTIONS=On"
    else
      args << "-DCMAKE_CXX_FLAGS_RELEASE='-DNDEBUG'"
    end

    mktemp do
      system "cmake", "-G", "Unix Makefiles", buildpath, *(std_cmake_args + args)
      system "make"
      system "make", "install"
    end

    if build.with? "clang"
      system "make", "-C", "projects/libcxx", "install",
        "DSTROOT=#{prefix}", "SYMROOT=#{buildpath}/projects/libcxx"

      (share/"clang/tools").install Dir["tools/clang/tools/scan-{build,view}"]
      inreplace "#{share}/clang/tools/scan-build/scan-build", "$RealBin/bin/clang", "#{bin}/clang"
      bin.install_symlink share/"clang/tools/scan-build/scan-build", share/"clang/tools/scan-view/scan-view"
      man1.install_symlink share/"clang/tools/scan-build/scan-build.1"
    end

    # install llvm python bindings
    (lib/"python2.7/site-packages").install buildpath/"bindings/python/llvm"
    (lib/"python2.7/site-packages").install buildpath/"tools/clang/bindings/python/clang" if build.with? "clang"
  end

  def caveats
    <<-EOS.undent
      LLVM executables are installed in #{opt_bin}.
      Extra tools are installed in #{opt_share}/llvm.
    EOS
  end

  test do
    system "#{bin}/llvm-config", "--version"
  end
end
