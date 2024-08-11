class Qca < Formula
  desc '"Qt Cryptographic Architecture (QCA)'
  homepage 'https://userbase.kde.org/QCA/'
  head 'https://invent.kde.org/libraries/qca.git'

  stable do
    url 'https://download.kde.org/stable/qca/2.3.9/qca-2.3.9.tar.xz'
    sha256 'c555d5298cdd7b6bafe2b1f96106f30cfa543a23d459d50c8a91eac33c476e4e'
  end

  option "with-api-docs", "Build API documentation"

  depends_on "cmake" => :build
  depends_on "pkg-config" => :build
  depends_on "qt5"

  # Plugins (QCA needs at least one plugin to do anything useful)
  depends_on "openssl" # qca-ossl
  depends_on "botan" => :optional # qca-botan
  depends_on "libgcrypt" => :optional # qca-gcrypt
  depends_on "gnupg" => :optional # qca-gnupg
  depends_on "nss" => :optional # qca-nss
  depends_on "pkcs11-helper" => :optional # qca-pkcs11

  if build.with? "api-docs"
    depends_on "graphviz" => :build
    depends_on "doxygen" => [:build, "with-graphviz"]
  end

  def install
    args = std_cmake_args
    args << "-DQT4_BUILD=OFF"
    args << "-DBUILD_TESTS=OFF"

    # Plugins (qca-ossl, qca-cyrus-sasl, qca-logger, qca-softstore always built)
    args << "-DWITH_botan_PLUGIN=#{build.with?("botan") ? "YES" : "NO"}"
    args << "-DWITH_gcrypt_PLUGIN=#{build.with?("libgcrypt") ? "YES" : "NO"}"
    args << "-DWITH_gnupg_PLUGIN=#{build.with?("gnupg") ? "YES" : "NO"}"
    args << "-DWITH_nss_PLUGIN=#{build.with?("nss") ? "YES" : "NO"}"
    args << "-DWITH_pkcs11_PLUGIN=#{build.with?("pkcs11-helper") ? "YES" : "NO"}"

    system "cmake", ".", *args
    system "make", "install"

    if build.with? "api-docs"
      system "make", "doc"
      doc.install "apidocs/html"
    end
  end

  test do
    system "#{bin}/qcatool", "--noprompt", "--newpass=",
                             "key", "make", "rsa", "2048", "test.key"
  end
end
