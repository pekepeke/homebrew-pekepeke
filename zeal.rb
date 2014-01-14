require "formula"

class Zeal < Formula
  homepage "http://zealdocs.org/"
  version '0.0.0'
  url "https://github.com/jkozera/zeal.git"
  sha1 "6e3feb617d5ef02bd77d3aea43b209aef1ac7dc0"
  head "https://github.com/jkozera/zeal.git"

  # depends_on "cmake" => :build
  depends_on "qt5"

  def install
    qt5 = Formula.factory('qt5')
    # ENV.deparallelize  # if your formula fails when building in parallel
    ENV.append 'CFLAGS', '-I#{qt5.installed_prefix}/include'
    ENV.append 'LDLAGS', '-L#{qt5.installed_prefix}/lib'

    Dir.chdir('zeal') do
      curl "https://github.com/pekepeke/osx_library/raw/master/tools/ApplicationIcons/zeal.icns", '--output', "zeal.icns"
      system 'echo "ICON = zeal.icns" >> zeal.pro'
      system "#{qt5.installed_prefix}/bin/qmake"
      # Remove unrecognized options if warned by configure
      # system "./configure", "--disable-debug",
      #                       "--disable-dependency-tracking",
      #                       "--disable-silent-rules",
      #                       "--prefix=#{prefix}"
      # system "cmake", ".", *std_cmake_args
      system "make"
      prefix.install "zeal.app"
    end
  end

  # test do
  #   # `test do` will create, run in and delete a temporary directory.
  #   #
  #   # This test will fail and we won't accept that! It's enough to just replace
  #   # "false" with the main program this formula installs, but it'd be nice if you
  #   # were more thorough. Run the test with `brew test zeal`.
  #   #
  #   # The installed folder is not in the path, so use the entire path to any
  #   # executables being tested: `system "#{bin}/program", "do", "something"`.
  #   system "false"
  # end
end
