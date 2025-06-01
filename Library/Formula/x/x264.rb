class X264 < Formula
  desc 'H.264/AVC encoder'
  homepage 'https://www.videolan.org/developers/x264.html'
  # the latest commit on the stable branch
  url 'https://code.videolan.org/videolan/x264/-/archive/31e19f92f00c7003fa115047ce50978bc98c3a0d/x264-31e19f92f00c7003fa115047ce50978bc98c3a0d.tar.bz2'
  version '20231001'
  sha256 '01a4acb74eea1118c3aa96c3e18ee3384bc1f2bc670f31fb0f63be853e4d9d08'

  head 'https://code.videolan.org/videolan/x264.git'

  devel do
    # the latest commit on the master branch
    url 'https://code.videolan.org/videolan/x264/-/archive/85b5ccea1fab98841d79455e344c797c5ffc3212/x264-85b5ccea1fab98841d79455e344c797c5ffc3212.tar.bz2'
    version '20250521'
    sha256 '9c1e9cacbb96e533dae8ba22cd86fe49b27bbd77a012d5b79a476d920bcd4e99'
  end

  option :universal
  option 'with-mp4=', 'Depend on either the gpac or the l-smash library to support MPEG4'

  depends_on :ld64

  case ARGV.value 'with-mp4'
    when 'gpac' then depends_on 'gpac'
    when 'l-smash' then depends_on 'l-smash'
  end

  # For whatever reason, GCC doesn’t like the specific builtin names used in the source.
  patch :DATA if CPU.type == :powerpc and [:gcc, :llvm, :gcc_4_0].include? ENV.compiler

  def install
    ENV.universal_binary if build.universal?

    # On PPC Darwin, x264 always uses -fastf, which isn't supported by FSF GCC.
    # On the other hand, -fno-lto isn’t known to Apple GCC.
    if [:gcc, :llvm, :gcc_4_0].include? ENV.compiler
      inreplace 'configure', '-fno-lto', ''
    else
      inreplace 'configure', '-fastf', ''
    end

    # on powerpc/powerpc64, the configure script hard-codes a G4 CPU
    if CPU.type == :powerpc
      inreplace 'configure', '-mcpu=G4', CPU.optimization_flags
    end

    args = %W[
        --prefix=#{prefix}
        --bashcompletionsdir=#{bash_completion}
        --enable-pic
        --enable-shared
        --enable-static
        --enable-strip
      ]
    system './configure', *args
    system 'make'
    system 'make', 'install'
  end # install

  test do
    (testpath/'test.c').write <<-EOS.undent
      #include <stdint.h>
      #include <x264.h>

      int main()
      {
          x264_picture_t pic;
          x264_picture_init(&pic);
          x264_picture_alloc(&pic, 1, 1, 1);
          x264_picture_clean(&pic);
          return 0;
      }
    EOS
    system ENV.cc, '-lx264', 'test.c', '-o', 'test'
    arch_system('./test')
  end # do test
end # X264

__END__
--- old/common/ppc/mc.c
+++ new/common/ppc/mc.c
@@ -822,15 +822,12 @@
 
     LOAD_ZERO;
 
-    vec_u16_t twov, fourv, fivev, sixv;
-    vec_s16_t sixteenv, thirtytwov;
-
-    twov = vec_splats( (uint16_t)2 );
-    fourv = vec_splats( (uint16_t)4 );
-    fivev = vec_splats( (uint16_t)5 );
-    sixv = vec_splats( (uint16_t)6 );
-    sixteenv = vec_splats( (int16_t)16 );
-    thirtytwov = vec_splats( (int16_t)32 );
+    vec_u16_t twov = vec_splat_u16(2);
+    vec_u16_t fourv = vec_splat_u16(4);
+    vec_u16_t fivev = vec_splat_u16(5);
+    vec_u16_t sixv = vec_splat_u16(6);
+    vec_s16_t sixteenv = {16,16,16,16,16,16,16,16};
+    vec_s16_t thirtytwov = {32,32,32,32,32,32,32,32};
 
     for( int y = 0; y < i_height; y++ )
     {
@@ -1005,17 +1002,19 @@
     LOAD_ZERO;
     vec_u8_t srcv;
     vec_s16_t weightv;
-    vec_s16_t scalev, offsetv, denomv, roundv;
+    vec_s16_t denomv, roundv;
 
     int denom = weight->i_denom;
+    vec_s16_t pdenomv = {denom,denom,denom,denom,denom,denom,denom,denom};
+    vec_s16_t proundv = {(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1))};
 
-    scalev = vec_splats( (int16_t)weight->i_scale );
-    offsetv = vec_splats( (int16_t)weight->i_offset );
+    vec_s16_t scalev = {weight->i_scale,weight->i_scale,weight->i_scale,weight->i_scale,weight->i_scale,weight->i_scale,weight->i_scale,weight->i_scale};
+    vec_s16_t offsetv = {weight->i_offset,weight->i_offset,weight->i_offset,weight->i_offset,weight->i_offset,weight->i_offset,weight->i_offset,weight->i_offset};
 
     if( denom >= 1 )
     {
-        denomv = vec_splats( (int16_t)denom );
-        roundv = vec_splats( (int16_t)(1 << (denom - 1)) );
+        denomv = pdenomv;
+        roundv = proundv;
 
         for( int y = 0; y < i_height; y++, dst += i_dst, src += i_src )
         {
@@ -1050,17 +1049,19 @@
     LOAD_ZERO;
     vec_u8_t srcv;
     vec_s16_t weightv;
-    vec_s16_t scalev, offsetv, denomv, roundv;
+    vec_s16_t denomv, roundv;
 
     int denom = weight->i_denom;
+    vec_s16_t pdenomv = {denom,denom,denom,denom,denom,denom,denom,denom};
+    vec_s16_t proundv = {(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1))};
 
-    scalev = vec_splats( (int16_t)weight->i_scale );
-    offsetv = vec_splats( (int16_t)weight->i_offset );
+    vec_s16_t scalev = {weight->i_scale,weight->i_scale,weight->i_scale,weight->i_scale,weight->i_scale,weight->i_scale,weight->i_scale,weight->i_scale};
+    vec_s16_t offsetv = {weight->i_offset,weight->i_offset,weight->i_offset,weight->i_offset,weight->i_offset,weight->i_offset,weight->i_offset,weight->i_offset};
 
     if( denom >= 1 )
     {
-        denomv = vec_splats( (int16_t)denom );
-        roundv = vec_splats( (int16_t)(1 << (denom - 1)) );
+        denomv = pdenomv;
+        roundv = proundv;
 
         for( int y = 0; y < i_height; y++, dst += i_dst, src += i_src )
         {
@@ -1095,17 +1096,19 @@
     LOAD_ZERO;
     vec_u8_t srcv;
     vec_s16_t weightv;
-    vec_s16_t scalev, offsetv, denomv, roundv;
+    vec_s16_t denomv, roundv;
 
     int denom = weight->i_denom;
+    vec_s16_t pdenomv = {denom,denom,denom,denom,denom,denom,denom,denom};
+    vec_s16_t proundv = {(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1))};
 
-    scalev = vec_splats( (int16_t)weight->i_scale );
-    offsetv = vec_splats( (int16_t)weight->i_offset );
+    vec_s16_t scalev = {weight->i_scale,weight->i_scale,weight->i_scale,weight->i_scale,weight->i_scale,weight->i_scale,weight->i_scale,weight->i_scale};
+    vec_s16_t offsetv = {weight->i_offset,weight->i_offset,weight->i_offset,weight->i_offset,weight->i_offset,weight->i_offset,weight->i_offset,weight->i_offset};
 
     if( denom >= 1 )
     {
-        denomv = vec_splats( (int16_t)denom );
-        roundv = vec_splats( (int16_t)(1 << (denom - 1)) );
+        denomv = pdenomv;
+        roundv = proundv;
 
         for( int y = 0; y < i_height; y++, dst += i_dst, src += i_src )
         {
@@ -1140,17 +1143,19 @@
     LOAD_ZERO;
     vec_u8_t srcv;
     vec_s16_t weight_lv, weight_hv;
-    vec_s16_t scalev, offsetv, denomv, roundv;
+    vec_s16_t denomv, roundv;
 
     int denom = weight->i_denom;
+    vec_s16_t pdenomv = {denom,denom,denom,denom,denom,denom,denom,denom};
+    vec_s16_t proundv = {(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1))};
 
-    scalev = vec_splats( (int16_t)weight->i_scale );
-    offsetv = vec_splats( (int16_t)weight->i_offset );
+    vec_s16_t scalev = {weight->i_scale,weight->i_scale,weight->i_scale,weight->i_scale,weight->i_scale,weight->i_scale,weight->i_scale,weight->i_scale};
+    vec_s16_t offsetv = {weight->i_offset,weight->i_offset,weight->i_offset,weight->i_offset,weight->i_offset,weight->i_offset,weight->i_offset,weight->i_offset};
 
     if( denom >= 1 )
     {
-        denomv = vec_splats( (int16_t)denom );
-        roundv = vec_splats( (int16_t)(1 << (denom - 1)) );
+        denomv = pdenomv;
+        roundv = proundv;
 
         for( int y = 0; y < i_height; y++, dst += i_dst, src += i_src )
         {
@@ -1191,12 +1196,14 @@
     LOAD_ZERO;
     vec_u8_t srcv, srcv2;
     vec_s16_t weight_lv, weight_hv, weight_3v;
-    vec_s16_t scalev, offsetv, denomv, roundv;
+    vec_s16_t denomv, roundv;
 
     int denom = weight->i_denom;
+    vec_s16_t pdenomv = {denom,denom,denom,denom,denom,denom,denom,denom};
+    vec_s16_t proundv = {(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1)),(1<<(denom-1))};
 
-    scalev = vec_splats( (int16_t)weight->i_scale );
-    offsetv = vec_splats( (int16_t)weight->i_offset );
+    vec_s16_t scalev = {weight->i_scale,weight->i_scale,weight->i_scale,weight->i_scale,weight->i_scale,weight->i_scale,weight->i_scale,weight->i_scale};
+    vec_s16_t offsetv = {weight->i_offset,weight->i_offset,weight->i_offset,weight->i_offset,weight->i_offset,weight->i_offset,weight->i_offset,weight->i_offset};
 
     if( denom >= 1 )
     {
@@ -1208,8 +1215,8 @@
             { round, round, round, round, 0, 0, 0, 0 },
         };
 
-        denomv = vec_splats( (int16_t)denom );
-        roundv = vec_splats( (int16_t)(1 << (denom - 1)) );
+        denomv = pdenomv;
+        roundv = proundv;
 
         for( int y = 0; y < i_height; y++, dst += i_dst, src += i_src )
         {
--- old/common/ppc/ppccommon.h
+++ new/common/ppc/ppccommon.h
@@ -150,7 +150,7 @@
  **********************************************************************/
 #ifndef __POWER9_VECTOR__
 #define VEC_STORE8( v, p ) \
-    vec_vsx_st( vec_xxpermdi( v, vec_vsx_ld( 0, p ), 1 ), 0, p )
+    vec_vsx_st( xxpermdi( v, vec_vsx_ld( 0, p ), 1 ), 0, p )
 #else
 #define VEC_STORE8( v, p ) vec_xst_len( v, p, 8 )
 #endif
@@ -322,15 +322,11 @@
 #elif (defined(__GNUC__) && (__GNUC__ > 6 || (__GNUC__ == 6 && __GNUC_MINOR__ >= 3))) || \
       (defined(__clang__) && __clang_major__ >= 7)
 #define xxpermdi(a, b, c) vec_xxpermdi(a, b, c)
-#endif
-
+#elif !defined(xxpermdi)
 // vec_xxpermdi has its endianness bias exposed in early gcc and clang
 #ifdef WORDS_BIGENDIAN
-#ifndef xxpermdi
 #define xxpermdi(a, b, c) vec_xxpermdi(a, b, c)
-#endif
 #else
-#ifndef xxpermdi
 #define xxpermdi(a, b, c) vec_xxpermdi(b, a, ((c >> 1) | (c & 1) << 1) ^ 3)
 #endif
 #endif
--- old/common/ppc/quant.c
+++ new/common/ppc/quant.c
@@ -70,7 +70,7 @@
 {
     LOAD_ZERO;
     vector bool short mskA;
-    vec_u32_t i_qbitsv = vec_splats( (uint32_t)16 );
+    vec_u32_t i_qbitsv = {16,16,16,16};
     vec_u16_t coefvA;
     vec_u32_t multEvenvA, multOddvA;
     vec_u16_t mfvA;
@@ -93,7 +93,7 @@
 int x264_quant_4x4x4_altivec( dctcoef dcta[4][16], udctcoef mf[16], udctcoef bias[16] )
 {
     LOAD_ZERO;
-    vec_u32_t i_qbitsv = vec_splats( (uint32_t)16 );
+    vec_u32_t i_qbitsv = {16,16,16,16};
     vec_s16_t one = vec_splat_s16( 1 );
     vec_s16_t nz0, nz1, nz2, nz3;
 
@@ -326,7 +326,7 @@
 {
     LOAD_ZERO;
     vector bool short mskA;
-    vec_u32_t i_qbitsv;
+    vec_u32_t i_qbitsv = {16,16,16,16};
     vec_u16_t coefvA;
     vec_u32_t multEvenvA, multOddvA;
     vec_s16_t one = vec_splat_s16(1);
@@ -338,12 +338,8 @@
 
     vec_s16_t temp1v, temp2v;
 
-    vec_u16_t mfv;
-    vec_u16_t biasv;
-
-    mfv = vec_splats( (uint16_t)mf );
-    i_qbitsv = vec_splats( (uint32_t) 16 );
-    biasv = vec_splats( (uint16_t)bias );
+    vec_u16_t mfv = {mf,mf,mf,mf,mf,mf,mf,mf};
+    vec_u16_t biasv = {bias,bias,bias,bias,bias,bias,bias,bias};
 
     QUANT_16_U_DC( 0, 16 );
     return vec_any_ne(nz, zero_s16v);
@@ -373,7 +369,7 @@
 {
     LOAD_ZERO;
     vector bool short mskA;
-    vec_u32_t i_qbitsv;
+    vec_u32_t i_qbitsv = {16,16,16,16};
     vec_u16_t coefvA;
     vec_u32_t multEvenvA, multOddvA;
     vec_s16_t one = vec_splat_s16(1);
@@ -382,12 +378,8 @@
 
     vec_s16_t temp1v, temp2v;
 
-    vec_u16_t mfv;
-    vec_u16_t biasv;
-
-    mfv = vec_splats( (uint16_t)mf );
-    i_qbitsv = vec_splats( (uint32_t) 16 );
-    biasv = vec_splats( (uint16_t)bias );
+    vec_u16_t mfv = {mf,mf,mf,mf,mf,mf,mf,mf};
+    vec_u16_t biasv = {bias,bias,bias,bias,bias,bias,bias,bias};
 
     QUANT_4_U_DC(0);
     return vec_any_ne(vec_and(nz, mask2), zero_s16v);
@@ -397,7 +389,7 @@
 {
     LOAD_ZERO;
     vector bool short mskA;
-    vec_u32_t i_qbitsv;
+    vec_u32_t i_qbitsv = {16,16,16,16};
     vec_u16_t coefvA;
     vec_u32_t multEvenvA, multOddvA;
     vec_u16_t mfvA;
@@ -413,8 +405,6 @@
 
     vec_s16_t temp1v, temp2v, tmpv;
 
-    i_qbitsv = vec_splats( (uint32_t)16 );
-
     for( int i = 0; i < 4; i++ )
         QUANT_16_U( i*2*16, i*2*16+16 );
     return vec_any_ne(nz, zero_s16v);
@@ -482,8 +472,7 @@
 
     if( i_qbits >= 0 )
     {
-        vec_u16_t i_qbitsv;
-        i_qbitsv = vec_splats( (uint16_t) i_qbits );
+        vec_u16_t i_qbitsv = {i_qbits,i_qbits,i_qbits,i_qbits,i_qbits,i_qbits,i_qbits,i_qbits};
 
         for( int y = 0; y < 4; y+=2 )
             DEQUANT_SHL();
@@ -492,14 +481,11 @@
     {
         const int f = 1 << (-i_qbits-1);
 
-        vec_s32_t fv;
-        fv = vec_splats( f );
+        vec_s32_t fv = {f,f,f,f};
 
-        vec_u32_t i_qbitsv;
-        i_qbitsv = vec_splats( (uint32_t)-i_qbits );
+        vec_u32_t i_qbitsv = {-i_qbits,-i_qbits,-i_qbits,-i_qbits};
 
-        vec_u32_t sixteenv;
-        sixteenv = vec_splats( (uint32_t)16 );
+        vec_u32_t sixteenv = {16,16,16,16};
 
         for( int y = 0; y < 4; y+=2 )
             DEQUANT_SHR();
@@ -520,8 +506,7 @@
 
     if( i_qbits >= 0 )
     {
-        vec_u16_t i_qbitsv;
-        i_qbitsv = vec_splats((uint16_t)i_qbits );
+        vec_u16_t i_qbitsv = {i_qbits,i_qbits,i_qbits,i_qbits,i_qbits,i_qbits,i_qbits,i_qbits};
 
         for( int y = 0; y < 16; y+=2 )
             DEQUANT_SHL();
@@ -530,14 +515,11 @@
     {
         const int f = 1 << (-i_qbits-1);
 
-        vec_s32_t fv;
-        fv = vec_splats( f );
+        vec_s32_t fv = {f,f,f,f};
 
-        vec_u32_t i_qbitsv;
-        i_qbitsv = vec_splats( (uint32_t)-i_qbits );
+        vec_u32_t i_qbitsv = {-i_qbits,-i_qbits,-i_qbits,-i_qbits};
 
-        vec_u32_t sixteenv;
-        sixteenv = vec_splats( (uint32_t)16 );
+        vec_u32_t sixteenv = {16,16,16,16};
 
         for( int y = 0; y < 16; y+=2 )
             DEQUANT_SHR();
--- old/Makefile
+++ new/Makefile
@@ -275,7 +275,7 @@
 $(OBJS) $(OBJSO): CFLAGS += $(CFLAGSSO)
 $(OBJCLI): CFLAGS += $(CFLAGSCLI)
 
-$(OBJS) $(OBJASM) $(OBJSO) $(OBJCLI) $(OBJCHK) $(OBJCHK_8) $(OBJCHK_10) $(OBJEXAMPLE): .depend
+$(OBJS) $(OBJASM) $(OBJSO) $(OBJCLI) $(OBJCHK) $(OBJCHK_8) $(OBJCHK_10) $(OBJEXAMPLE): $(GENERATED)
 
 %.o: %.c
 	$(CC) $(CFLAGS) -c $< $(CC_O)
