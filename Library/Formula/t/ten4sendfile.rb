class Ten4sendfile < Formula
  desc 'Sendfile(2) implementation for Mac OS X Tiger'
  homepage 'https://github.com/gsteemso/ten4sendfile/'
  head 'https://github.com/gsteemso/ten4sendfile.git', :branch => 'main'

  depends_on MaximumMacOSRequirement.new(:tiger)

  def install
    system 'make', "prefix=#{prefix}", 'install'
  end

  def caveats
    <<-_.undent
      Software which needs to use the sendfile function must add
          -isystem #{opt_include}
      to CPPFLAGS whenever compiling a software unit that uses sendfile(2).  Doing so
      will interpose Ten4Sendfile’s <sys/socket.h> shim, making the sendfile function
      visible to your software.
    _
  end # caveats
end # Ten4sendfile
