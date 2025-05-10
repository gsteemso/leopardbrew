class Expat < Formula
  desc "XML 1.0 parser"
  homepage "http://www.libexpat.org"
  url "https://github.com/libexpat/libexpat/releases/download/R_2_6_4/expat-2.6.4.tar.lz"
  sha256 '80a5bec283c7cababb3c6ec145feb4f34a7741eae69f9e6654cc82f5890f05e2'

  head "https://github.com/libexpat/libexpat.git"

  keg_only :provided_by_osx, "OS X includes Expat 1.5." if MacOS.version > :tiger

  option :universal

  def install
    ENV.universal_binary if build.universal?

    args = %W[
      --prefix=#{prefix}
      --mandir=#{man}
      --disable-dependency-tracking
      --disable-silent-rules
    ]
    args << '--without-tests' unless ENV.supports_cxx11?

    system "./configure", *args
    system "make", "install"
  end

  test do
    (testpath/"test.c").write <<-EOS.undent
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
    system ENV.cc, "test.c", "-lexpat", "-o", "test"
    assert_equal "tag:str|data:Hello, world!|", shell_output("./test")
  end
end
