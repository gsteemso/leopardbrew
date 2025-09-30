# stable release 2025-03-27; checked 2025-08-04
class Expat < Formula
  desc 'Stream‐oriented XML parser'
  homepage 'https://libexpat.github.io/'
  url 'https://github.com/libexpat/libexpat/releases/download/R_2_7_1/expat-2.7.1.tar.lz'
  sha256 'baacdd8d98d5d3b753f2a2780d84b0bc7731be11cacdc1b98cb8ad73f0504e68'

  head 'https://github.com/libexpat/libexpat.git'

  keg_only :provided_by_osx, 'Mac OS includes Expat 1.5' if MacOS.version > :tiger

  option :universal

  def install
    ENV.universal_binary if build.universal?

    args = %W[
      --prefix=#{prefix}
      --mandir=#{man}
      --disable-dependency-tracking
      --disable-silent-rules
    ]
    args << '--without-tests' unless ENV.supports? :cxx11

    system './configure', *args
    system 'make', 'install'
  end # install

  test do
    (testpath/'test.c').write <<-EOS.undent
      #include <stdio.h>
      #include "expat.h"

      static void XMLCALL my_StartElementHandler(
        void *userdata,
        const XML_Char *name,
        const XML_Char **atts)
      {
        printf("tag:%s|", name);
      }

      static void XMLCALL my_CharacterDataHandler(
        void *userdata,
        const XML_Char *s,
        int len)
      {
        printf("data:%.*s|", len, s);
      }

      int main()
      {
        static const char str[] = "<str>Hello, world!</str>";
        int result;

        XML_Parser parser = XML_ParserCreate("utf-8");
        XML_SetElementHandler(parser, my_StartElementHandler, NULL);
        XML_SetCharacterDataHandler(parser, my_CharacterDataHandler);
        result = XML_Parse(parser, str, sizeof(str), 1);
        XML_ParserFree(parser);

        return result;
      }
    EOS
    ENV.universal_binary if build.universal?
    system ENV.cc, 'test.c', '-lexpat', '-o', 'test'
    assert_equal 'tag:str|data:Hello, world!|', shell_output('./test')
  end # test
end # Expat
