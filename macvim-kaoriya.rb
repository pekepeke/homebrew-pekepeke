require 'formula'

class MacvimKaoriya < Formula
  homepage 'http://code.google.com/p/macvim-kaoriya/'
  head 'https://github.com/splhack/macvim.git'
  version '7.3.969'

  depends_on 'cmigemo-mk'
  depends_on 'ctags-objc-ja'
  depends_on 'gettext-mk'
  # depends_on 'lua'

  def ptches
    patch_level = version.to_s.split('.').last.to_i
    {'p0' => (807..patch_level).map { |i| 'ftp://ftp.vim.org/pub/vim/patches/7.3/7.3.%03d' % i }}
  end


  def install
    ENV.remove_macosxsdk
    ENV.macosxsdk '10.7'
    ENV.append 'MACOSX_DEPLOYMENT_TARGET', '10.7'
    # ENV.append 'CFLAGS', '-mmacosx-version-min=10.7'
    # ENV.append 'LDFLAGS', '-mmacosx-version-min=10.7 -headerpad_max_install_names'
    ENV.append 'CFLAGS', "-mmacosx-version-min=10.7 -I#{HOMEBREW_PREFIX}/opt/gettext-mk/include"
    ENV.append 'LDFLAGS', "-mmacosx-version-min=10.7 -headerpad_max_install_names -L#{HOMEBREW_PREFIX}/opt/gettext-mk/lib"
    ENV.append 'VERSIONER_PERL_VERSION', '5.12'
    ENV.append 'VERSIONER_PYTHON_VERSION', '2.7'
    ENV.append 'vi_cv_path_python3', "#{HOMEBREW_PREFIX}/bin/python3"
    ENV.append 'vi_cv_path_ruby19', "#{HOMEBREW_PREFIX}/bin/ruby19"

    opts = []

    lua = Formula.factory('lua')
    if lua.installed?
      opts << '--enable-luainterp'
      opts << "--with-lua-prefix=#{HOMEBREW_PREFIX}"
    end

    system './configure', "--prefix=#{prefix}",
      '--with-features=huge',
      '--enable-multibyte',
      '--enable-netbeans',
      '--with-tlib=ncurses',
      '--enable-cscope',
      '--enable-perlinterp=dynamic',
      '--enable-pythoninterp=dynamic',
      '--enable-python3interp=dynamic',
      '--enable-rubyinterp=dynamic',
      '--enable-ruby19interp=dynamic',
      *opts

    `rm src/po/ja.sjis.po`
    `touch src/po/ja.sjis.po`

    gettext = "#{Formula.factory('gettext-mk').prefix}/bin/"
    inreplace 'src/po/Makefile' do |s|
      s.gsub! /^(MSGFMT\s*=.*)(msgfmt.*)/, "\\1#{gettext}\\2"
      s.gsub! /^(XGETTEXT\s*=.*)(xgettext.*)/, "\\1#{gettext}\\2"
      s.gsub! /^(MSGMERGE\s*=.*)(msgmerge.*)/, "\\1#{gettext}\\2"
    end

    inreplace 'src/auto/config.mk' do |s|
      # s.gsub! "-L#{Formula.factory('readline').prefix}/lib", ''
      s.gsub! "-L#{HOMEBREW_PREFIX}/Cellar/readline/6.2.2/lib", ''
    end

    Dir.chdir('src/po') {system 'make'}
    system 'make'

    prefix.install 'src/MacVim/build/Release/MacVim.app'

    app = prefix + 'MacVim.app/Contents'
    macos = app + 'MacOS'
    runtime = app + 'Resources/vim/runtime'

    macos.install 'src/MacVim/mvim'
    mvim = macos + 'mvim'
    ['vimdiff', 'view', 'mvimdiff', 'mview'].each do |t|
      ln_s 'mvim', macos + t
    end
    inreplace mvim do |s|
      s.gsub! /^# (VIM_APP_DIR=).*/, "\\1`dirname \"$0\"`/../../.."
      s.gsub! /^(binary=).*/, "\\1\"`(cd \"$VIM_APP_DIR/MacVim.app/Contents/MacOS\"; pwd -P)`/Vim\""
    end

    cp "#{HOMEBREW_PREFIX}/bin/ctags", macos

    dict = runtime + 'dict'
    mkdir_p dict
    Dir.glob("#{HOMEBREW_PREFIX}/share/migemo/utf-8/*").each do |f|
      cp f, dict
    end

    libs = [
      "#{HOMEBREW_PREFIX}/lib/libmigemo.1.1.0.dylib",
    ]
    libs << "#{HOMEBREW_PREFIX}/lib/lib#{lua.name}.#{lua.version}.dylib" if lua.installed?

    libs.each do |lib|
      newname = "@executable_path/../Frameworks/#{File.basename(lib)}"
      system "install_name_tool -change #{lib} #{newname} #{macos + 'Vim'}"
      cp lib, app + 'Frameworks'
    end

    lib = "#{HOMEBREW_PREFIX}/opt/gettext-mk/lib/libintl.8.dylib"
    begin
      safe_system "otool -L #{macos + 'Vim'} | grep #{lib}"
    rescue ErrorDuringExecution => e
      gettext = Formula.factory('gettext')
      if gettext.installed?
        # overrides homebrew gettext
        lib = "#{HOMEBREW_PREFIX}/lib/libintl.8.dylib"
      end
    end
    newname = "@executable_path/../Frameworks/#{File.basename(lib)}"
    system "install_name_tool -change #{lib} #{newname} #{macos + 'Vim'}"
    cp lib, app + 'Frameworks'
  end
end
