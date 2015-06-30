require 'formula'

class MacvimKaoriya < Formula
  homepage 'https://github.com/splhack/macvim-kaoriya'
  # https://github.com/splhack/macvim/blob/master/src/version.c
  version '7.4.752'
  head 'https://github.com/splhack/macvim.git'
  url 'https://github.com/splhack/macvim.git'
  sha1 '4bfde446e64fa3c594711aa92ea428a4f7f1a736'

  option "with-luajit", "Build with luajit"
  option "with-lua", "Build with lua"
  option "icon-beautify", "Build with icon(http://cl.ly/0f18090S3d2W/download/MacVim.icns)"

  depends_on 'cmigemo-mk' => :build
  depends_on 'ctags-objc-ja' => :build
  depends_on 'gettext-mk' => :build

  depends_on 'luajit' => :optional
  depends_on 'lua' => :optional

  def patches
    # patch_level = version.to_s.split('.').last.to_i
    # {
    #   'p0' => (10..patch_level).map { |i| 'ftp://ftp.vim.org/pub/vim/patches/7.3/7.3.%03d' % i },
    # }
    {
      :p1 => [
        'https://bitbucket.org/koron/vim-kaoriya-patches/raw/6658116d59073a4471a83fea41a0791718773a96/X010-autoload_cache.diff',
        'https://gist.github.com/Shougo/5654189/raw'
      ]
    }
  end


  def install
    cmigemo = Formula.factory('cmigemo-mk')

    ENV["HOMEBREW_OPTFLAGS"] = "-march=core2" if build.with? 'binary-release'
    ENV.remove_macosxsdk
    ENV.macosxsdk '10.8'
    ENV.append 'MACOSX_DEPLOYMENT_TARGET', '10.8'
    ENV.append 'CFLAGS', "-mmacosx-version-min=10.8 -I#{HOMEBREW_PREFIX}/opt/gettext-mk/include -I#{cmigemo.installed_prefix}/include"
    ENV.append 'LDFLAGS', "-mmacosx-version-min=10.8 -headerpad_max_install_names -L#{HOMEBREW_PREFIX}/opt/gettext-mk/lib -L#{cmigemo.installed_prefix}/lib"
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
    elsif build.include? "with-lua"
      lua = Formula.factory('lua')
    end

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

    gettext = "#{Formula.factory('gettext-mk').installed_prefix}/bin/"
    inreplace 'src/po/Makefile' do |s|
      s.gsub! /^(XGETTEXT\s*=.*)(xgettext.*)/, "\\1#{gettext}\\2"
      s.gsub! /^(MSGMERGE\s*=.*)(msgmerge.*)/, "\\1#{gettext}\\2"
    end

    Dir.chdir('src/po') {system 'make'}
    system 'make'

    prefix.install 'src/MacVim/build/Release/MacVim.app'

    app = prefix + 'MacVim.app/Contents'
    frameworks = app + 'Frameworks'
    macos = app + 'MacOS'
    vimdir = app + 'Resources/vim'
    runtime = vimdir + 'runtime'
    docja = vimdir + 'plugins/vimdoc-ja/doc'

    system "#{macos + 'Vim'} -c 'helptags #{docja}' -c q"

    macos.install 'src/MacVim/mvim'
    mvim = macos + 'mvim'
    ['vimdiff', 'view', 'mvimdiff', 'mview'].each do |t|
      ln_s 'mvim', macos + t
    end
    inreplace mvim do |s|
      s.gsub! /^# (VIM_APP_DIR=).*/, "\\1`dirname \"$0\"`/../../.."
      s.gsub! /^(binary=).*/, "\\1\"`(cd \"$VIM_APP_DIR/MacVim.app/Contents/MacOS\"; pwd -P)`/Vim\""
    end

    cp "#{Formula.factory('ctags-objc-ja').installed_prefix}/bin/ctags", macos

    dict = runtime + 'dict'
    mkdir_p dict
    Dir.glob("#{cmigemo.installed_prefix}/share/migemo/utf-8/*").each do |f|
      cp f, dict
    end

    resource("CMapResources").stage do
      cp 'CMap/UniJIS-UTF8-H', runtime/'print/UniJIS-UTF8-H.ps'
    end

    libs = [
      "#{HOMEBREW_PREFIX}/opt/cmigemo-mk/lib/libmigemo.1.dylib",
      "#{HOMEBREW_PREFIX}/opt/gettext-mk/lib/libintl.8.dylib"
    ]
    libs.each do |lib|
      newname = "@executable_path/../Frameworks/#{File.basename(lib)}"
      system "install_name_tool -change #{lib} #{newname} #{macos + 'Vim'}"
      cp lib, app + 'Frameworks'
    end

    luadylib = nil
    if lua && lua.name == "lua"
      luadylib = "#{HOMEBREW_PREFIX}/lib/lib#{lua.name}.#{lua.installed_version}.dylib"
    elsif lua && lua.name == "luajit"
      luadylib = "#{HOMEBREW_PREFIX}/lib/lib#{lua.name}-5.1.#{lua.installed_version}.dylib"
    elsif lua
      luadylib = "#{HOMEBREW_PREFIX}/lib/libluajit-5.1.#{lua.installed_version}.dylib"
    end

    if luadylib
      cp luadylib, app + 'Frameworks' if File.exist? luadylib
      File.open(vimdir + 'vimrc', 'r+').write <<EOL
let $LUA_DLL = simplify($VIM . '/../../Frameworks/#{File.basename(luadylib)}')
#{File.open(vimdir + 'vimrc').read}
EOL
    end
  end

  resource("CMapResources") do
    url 'https://github.com/adobe-type-tools/cmap-resources/raw/master/cmapresources_japan1-6.zip'
    sha1 '83b148d19d5ad6e2d15c638a14eeec77c8939451'
  end
end
