require 'formula'

class CtagsObjcJa < Formula
  homepage 'https://github.com/splhack/ctags-objc-ja'
  head 'https://github.com/splhack/ctags-objc-ja.git'
  url 'https://github.com/splhack/ctags-objc-ja.git', :revision => '0b6fe37868bdb6379da4428825c9d8157290dd7e'

  depends_on "autoconf" => :build
  keg_only 'This module for macvim-kaoriya'

  def install
    ENV.remove_macosxsdk
    ENV.macosxsdk '10.7'
    ENV.append 'LDFLAGS', '-mmacosx-version-min=10.7 -headerpad_max_install_names'

    system "autoconf"
    system "./configure", "--disable-debug", "--disable-dependency-tracking",
                          "--prefix=#{prefix}",
                          "--enable-macro-patterns",
                          "--enable-japanese-support",
                          "--with-readlib"
    system "make install"
  end
end
