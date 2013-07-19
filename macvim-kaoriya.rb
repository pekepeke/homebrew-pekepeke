require 'formula'

class MacvimKaoriya < Formula
  homepage 'http://code.google.com/p/macvim-kaoriya/'
  version '7.4a.009'
  head 'https://github.com/splhack/macvim.git'
  url 'https://github.com/splhack/macvim.git'
  sha1 'abc448877143bd125eff116aed573c538e0a4fb9'

  option "with-luajit", "Build with luajit"
  option "with-lua", "Build with lua"
  option "icon-beautify", "Build with icon(http://cl.ly/0f18090S3d2W/download/MacVim.icns)"

  depends_on 'cmigemo-mk'
  depends_on 'ctags-objc-ja'
  depends_on 'gettext-mk'
  # depends_on 'lua'

  depends_on 'luajit' => :optional
  depends_on 'lua' => :optional

  def patches
    # patch_level = version.to_s.split('.').last.to_i
    # {
    #   'p0' => (10..patch_level).map { |i| 'ftp://ftp.vim.org/pub/vim/patches/7.3/7.3.%03d' % i },
    #   # 'p1' => 'https://gist.github.com/pekepeke/5864150/raw/8e8949979509d7997713137e9ffe49f59522819c/macvim-kaoriya_luajit_v73.patch',
    # }
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
    ENV.append 'vi_cv_path_perl', '/usr/bin/perl'
    ENV.append 'vi_cv_path_python', '/usr/bin/python'
    ENV.append 'vi_cv_path_ruby', '/usr/bin/ruby'
    ENV.append 'vi_cv_path_python3', "#{HOMEBREW_PREFIX}/bin/python3"
    ENV.append 'vi_cv_path_ruby19', "#{HOMEBREW_PREFIX}/bin/ruby19"

    opts = []

    lua = nil
    if build.include? 'with-luajit'
      lua = Formula.factory('luajit')
    elsif build.include? "--with-lua"
      lua = Formula.factory('lua')
    end

    # if with_lua
    #   opts << '--enable-luainterp'
    #   # opts << "--with-lua-prefix=#{HOMEBREW_PREFIX}"
    #   opts << "--with-lua-prefix=#{lua.installed_prefix}"
    # end

    if build.include? "icon-beautify"
      curl "http://cl.ly/0f18090S3d2W/download/MacVim.icns", "--output", "src/MacVim/icons/MacVim.icns"
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
      '--enable-luainterp=dynamic',
      '--with-lua-prefix=/usr/local',
      '--enable-lua52interp=dynamic',
      '--with-lua52-prefix=/usr/local/Cellar/lua52/5.2.1',
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
    vimdir = app + 'Resources/vim'
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

    luadylib = nil
    if lua && lua.name == "lua"
      luadylib = "#{HOMEBREW_PREFIX}/lib/lib#{lua.name}.#{lua.installed_version}.dylib"
    elsif lua && lua.name == "luajit"
      luadylib = "#{HOMEBREW_PREFIX}/lib/lib#{lua.name}-5.1.#{lua.installed_version}.dylib"
    else
      luadylib = "#{HOMEBREW_PREFIX}/lib/libluajit-5.1.#{luajit}.dylib"
    end

    if luadylib
      cp luadylib, frameworks if File.exist? luadylib
    # File.open(vimdir + 'vimrc', 'a').write <<EOL
# let $LUA_DLL = simplify($VIM . '/../../Frameworks/#{File.basename(luadylib)}')
# EOL
    File.open(vimdir + 'vimrc', 'r+').write <<EOL
let $LUA_DLL = simplify($VIM . '/../../Frameworks/#{File.basename(luadylib)}')
#{File.open(vimdir + 'vimrc').read}
EOL
    end
  end
end
