require 'formula'

class Kdiff3Ja < Formula
  homepage 'http://kdiff3.sourceforge.net/'
  url 'git://git.code.sf.net/p/kdiff3/code', :revision => '4d116d1cb7e5ca0ed69a4c8e272253198bfbbb91'
  version '0.9.97'
  # sha1 '1f2828c4b287b905bac64992b46a3e9231319547'

  depends_on 'qt'

  option "with-icon", "make with custom icon"

  def patches
    'https://gist.github.com/pekepeke/5755291/raw/3373ecb08265f535b76d69de09635a4e3c24f012/kdiff3_mbyte_0_9_97.diff'
  end

  def install
    # configure builds the binary
    # cd "kdiff3" do
    #   # cp "", src-QT4/kdiff3.icns
    #   # system 'echo "ICON = kdiff3.icns" >> src-QT4/kdiff3.pro'
    #   system "./configure", "qt4"
    #   # bin.install "releaseQt/kdiff3.app/Contents/MacOS/kdiff3"
    #   prefix.install "releaseQt/kdiff3.app"
    # end
    cd "kdiff3/src-QT4" do
      if build.include? "with-icon"
        curl "https://github.com/pekepeke/osx_library/raw/master/tools/ApplicationIcons/kdiff3.icns", '--output', "kdiff3.icns"
        system 'echo "ICON = kdiff3.icns" >> kdiff3.pro'
      end
      system "qmake", "kdiff3.pro"
      system "qmake", "-spec", "macx-xcode", "kdiff3.pro"
      system "make"
      system "macdeployqt", "kdiff3.app", "-dmg"
      prefix.install "kdiff3.app"
      prefix.install "kdiff3.dmg"
    end

    # TODO : install_name_tool
    # app = prefix + "kdiff3.app/Contents"
    # macos = app + "MacOS"
    # mkdir app + 'Frameworks'
    # {
    #   "#{HOMEBREW_PREFIX}/lib/QtCore.framework" => "Versions/4/QtCore",
    #   "#{HOMEBREW_PREFIX}/lib/QtGui.framework" => "Versions/4/QtGui",
    # }.each do |lib, name|
    #   newname = "@executable_path/../Frameworks/#{File.basename(lib)}/#{name}"
    #   system "install_name_tool -change #{lib}/#{name} #{newname} #{macos + 'kdiff3'}"
    #   cp_r lib, app + 'Frameworks'
    # end
  end
end

