require "formula"

class Zeal < Formula
  homepage "http://zealdocs.org/"
  url "https://github.com/jkozera/zeal.git"
  head "https://github.com/jkozera/zeal.git"

  # version '0.0.0-0af21694d9'
  # sha1 "0af21694d91537e8917cbd2fde9fcab7804538b6"
  version '0.0.0-aaa5dff857'
  sha1 "aaa5dff85772921fc91397aa449e0f5316334506"

  # depends_on "cmake" => :build
  depends_on "qt5"

  def install
    qt5 = Formula.factory('qt5')
    # ENV.deparallelize  # if your formula fails when building in parallel
    ENV.append 'CFLAGS', '-I#{qt5.installed_prefix}/include'
    ENV.append 'LDLAGS', '-L#{qt5.installed_prefix}/lib'

    Dir.chdir('zeal') do
      # system "sed -i -e 's!unix:sources!# !' 3rdparty/qxtglobalshortcut/qxtglobalshortcut.pri"
      curl "https://github.com/pekepeke/osx_library/raw/master/tools/ApplicationIcons/zeal.icns", '--output', "zeal.icns"
      system 'echo "ICON = zeal.icns" >> zeal.pro'
      # system 'echo "config += create_prl" >> zeal.pro'
      # system 'echo "config += link_prl" >> zeal.pro'

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
