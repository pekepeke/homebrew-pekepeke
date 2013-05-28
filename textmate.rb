require 'formula'

# Documentation: https://github.com/mxcl/homebrew/wiki/Formula-Cookbook
# PLEASE REMOVE ALL GENERATED COMMENTS BEFORE SUBMITTING YOUR PULL REQUEST!

class Textmate < Formula
  homepage 'http://macromates.com/'
  version 'a9419'
  url 'http://api.textmate.org/downloads/release'
  sha1 '7582f447c0bb727facda7eaeb13b1e8da0bbeb3b'

  def install
    files = Dir::foreach('.').to_a.find_all {|f| f !~ %r[^\.*$] }
    mkdir 'TextMate.app'
    files.each do |f|
      mv f, "TextMate.app/#{f}"
    end
    prefix.install 'TextMate.app'
  end

  # url 'git://github.com/textmate/textmate.git'
  # sha1 '6d4cf22f13ab8a88c88788fe77b76d30473762bc'

  # depends_on 'ninja' => :build
  # depends_on 'ragel' => :build
  # depends_on 'boost' => :build
  # depends_on 'multimarkdown' => :build
  # depends_on 'mercurial' => :build
  # depends_on 'proctools' => :build

  # def install
  #   # ENV.j1  # if your formula's build system can't parallelize
  #   system "./configure", "--disable-debug", "--disable-dependency-tracking",
  #                         "--prefix=#{prefix}"
  #   system 'ninja TextMate'
  #   # system "cmake", ".", *std_cmake_args
  #   # system "make", "install" # if this fails, try separate make/make install steps
  # end

end
