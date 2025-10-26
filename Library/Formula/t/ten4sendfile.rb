class Ten4sendfile < Formula
  desc 'Sendfile(2) implementation for Mac OS 10.4 Tiger'
  homepage 'https://github.com/gsteemso/ten4sendfile/'
  head 'https://github.com/gsteemso/ten4sendfile.git', :branch => 'main'

  keg_only 'installs an overriding <sys/socket.h> header'

  depends_on MaximumMacOSRequirement.new(:tiger)

  def install
    system 'make', "prefix=#{prefix}", 'install'
  end
end # Ten4sendfile
