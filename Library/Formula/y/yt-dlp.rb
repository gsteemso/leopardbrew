class YtDlp < Formula
  desc 'feature‐rich command‐line audio/video downloader'
  homepage 'https://github.com/yt-dlp/yt-dlp'
  url 'https://github.com/yt-dlp/yt-dlp/archive/refs/tags/2025.05.22.zip'
  version '2025.05.22'
  sha256 'feb58fa22ff01261595c64a40907df9813b8c84b8847046f2da797a4b4f21147'

  depends_on 'ffmpeg'

  def install
    system './configure', "--prefix=#{prefix}",
                          '--disable-debug',
                          '--disable-dependency-tracking',
                          '--disable-silent-rules'
    system 'make', 'install'
  end # install

  test do
    system 'false'
  end
end # YtDlp
