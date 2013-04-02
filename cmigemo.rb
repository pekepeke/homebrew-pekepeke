require 'formula'

class Cmigemo < Formula
  url 'http://cmigemo.googlecode.com/files/cmigemo-default-src-20110227.zip'
  homepage 'http://www.kaoriya.net/software/cmigemo'
  sha1 '25e279c56d3a8f1e82cbfb3526d1b38742d1d66c'

  depends_on 'nkf'

  def patches
    # fix compile error
    DATA
  end

  def install
    File.chmod(0755, "./configure")
    system "./configure", "--prefix=#{prefix}"
    system "make osx"
    system "make osx-dict"
    Dir.chdir 'dict' do
      system "make utf-8"
    end
    mkdir "#{prefix}/lib"
    mkdir "#{prefix}/share"
    mkdir "#{prefix}/share/migemo"
    mkdir "#{prefix}/share/migemo/cp932"
    mkdir "#{prefix}/share/migemo/euc-jp"
    mkdir "#{prefix}/share/migemo/utf-8"
    system "make osx-install"
  end
end

__END__
--- a/src/wordbuf.c	2011-07-29 13:05:12.000000000 +0900
+++ b/src/wordbuf.c	2011-07-29 13:04:28.000000000 +0900
@@ -9,6 +9,7 @@
 #include <stdio.h>
 #include <stdlib.h>
 #include <string.h>
+#include <limits.h>
 #include "wordbuf.h"

 #define WORDLEN_DEF 64
