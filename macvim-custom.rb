require 'formula'

class MacvimCustom < Formula
  homepage 'http://code.google.com/p/macvim/'
  url 'https://github.com/b4winckler/macvim.git'
  version '7.3.1193'
  sha1 '946e2197253adb92fceef3fa9296c7b11ec41a1d'

  head 'https://github.com/b4winckler/macvim.git', :branch => 'master'

  # option "custom-icons", "Try to generate custom document icons"
  # option "override-system-vim", "Override system vim"
  option "with-python3", "Build with Python 3 scripting support"
  option "icon-beautify", "Build with icon(http://cl.ly/0f18090S3d2W/download/MacVim.icns)"

  depends_on 'ctags-objc-ja'
  # depends_on 'cscope'
  depends_on 'lua' => :optional
  depends_on 'luajit' => :optional

  depends_on :xcode # For xcodebuild.

  def patches
    patch_level = version.to_s.split('.').last.to_i
    {
      'p0' => (1194..patch_level).map { |i| 'ftp://ftp.vim.org/pub/vim/patches/7.3/7.3.%03d' % i },
      'p1' => 'https://gist.github.com/pekepeke/5794705/raw/bae53f52cbaeb3f8b0d82b8a6fa3891c7ee97859/macvim_luajit_v73.patch',
      # 'p1' => 'https://gist.github.com/pekepeke/5755279/raw/e6dc238aabd73bf8507f8d13c455b899d7094e0b/macvim_luajit_v73_1148.diff',
    }
  end

  def install
    # Set ARCHFLAGS so the Python app (with C extension) that is
    # used to create the custom icons will not try to compile in
    # PPC support (which isn't needed in Homebrew-supported systems.)
    arch = MacOS.prefer_64_bit? ? 'x86_64' : 'i386'
    ENV['ARCHFLAGS'] = "-arch #{arch}"

    # If building for 10.8, make sure that CC is set to "clang".
    # Reference: https://github.com/b4winckler/macvim/wiki/building
    ENV.clang if MacOS.version >= :mountain_lion

    ENV.remove_macosxsdk
    ENV.macosxsdk '10.7'
    ENV.append 'MACOSX_DEPLOYMENT_TARGET', '10.7'
    ENV.append 'CFLAGS', '-mmacosx-version-min=10.7'
    ENV.append 'LDFLAGS', '-mmacosx-version-min=10.7 -headerpad_max_install_names'
    ENV.append 'vi_cv_path_perl', '/usr/bin/perl'
    ENV.append 'vi_cv_path_python', '/usr/bin/python'
    ENV.append 'vi_cv_path_ruby', '/usr/bin/ruby'
    ENV.append 'vi_cv_path_python3', "#{HOMEBREW_PREFIX}/bin/python3"
    ENV.append 'vi_cv_path_ruby19', "#{HOMEBREW_PREFIX}/bin/ruby19"

    args = %W[
      --with-features=huge
      --with-tlib=ncurses
      --enable-multibyte
      --enable-netbeans
      --enable-cscope
      --with-macarchs=#{arch}
      --enable-perlinterp=dynamic
      --enable-pythoninterp=dynamic
      --enable-rubyinterp=dynamic
      --with-ruby-command=#{RUBY_PATH}
    ]
      # --enable-perlinterp=dynamic
      # --enable-perlinterp
      # --enable-pythoninterp
      # --enable-rubyinterp
      # --enable-ruby19interp=dynamic
      # --enable-tclinterp

    lua = Formula.factory('luajit')
    if lua.installed?
      args << "--with-luajit"
    else
      lua = Formula.factory('lua')
    end

    if build.include? "icon-beautify"
      curl "http://cl.ly/0f18090S3d2W/download/MacVim.icns", "--output", "src/MacVim/icons/MacVim.icns"
    end
    lua = Formula.factory('lua')
    if build.with? "lua" or lua.installed?
      args << "--enable-luainterp"
      args << "--with-lua-prefix=#{HOMEBREW_PREFIX}"
    end

    if build.include? "with-python3"
      args << "--enable-python3interp"
    end

    inreplace 'src/if_perl.xs' do |s|
      s.sub! /^(#define close_dll dlclose)/, <<-EOS
\\1
# if defined(MACOS_X_UNIX)
# define DYNAMIC_PERL_DLL "/System/Library/Perl/lib/5.10/libperl.dylib"
# else
# define DYNAMIC_PERL_DLL "libperl.so"
# endif
      EOS
    end
    system "./configure", *args

    # Building custom icons fails for many users, so off by default.
    # unless build.include? "custom-icons"
    inreplace "src/MacVim/icons/Makefile", "$(MAKE) -C makeicns", ""
    inreplace "src/MacVim/icons/make_icons.py", "dont_create = False", "dont_create = True"
    # end

    # Reference: https://github.com/b4winckler/macvim/wiki/building
    cd 'src/MacVim/icons' do
      system "make getenvy"
    end

    # cd 'src/po' do
    #   system 'make'
    # end

    system "make"

    prefix.install "src/MacVim/build/Release/MacVim.app"
    inreplace "src/MacVim/mvim", /^# VIM_APP_DIR=\/Applications$/,
                                 "VIM_APP_DIR=#{prefix}"
    app = prefix + 'MacVim.app/Contents'
    macos = app + 'MacOS'

    cp "#{HOMEBREW_PREFIX}/bin/ctags", macos

    libs = [
    ]
    libs << "#{HOMEBREW_PREFIX}/lib/lib#{lua.name}.#{lua.installed_version}.dylib" \
      if lua.installed? && lua.name == "lua"

    libs << "#{HOMEBREW_PREFIX}/lib/lib#{lua.name}.5.1.#{lua.installed_version}.dylib" \
      if lua.installed? && lua.name == "luajit"

    libs.each do |lib|
      newname = "@executable_path/../Frameworks/#{File.basename(lib)}"
      system "install_name_tool -change #{lib} #{newname} #{macos + 'Vim'}"
      cp lib, app + 'Frameworks'
    end

    # bin.install "src/MacVim/mvim"

    # Create MacVim vimdiff, view, ex equivalents
    # executables = %w[mvimdiff mview mvimex gvim gvimdiff gview gvimex]
    # executables += %w[vi vim vimdiff view vimex] if build.include? "override-system-vim"
    # executables.each {|f| ln_s bin+'mvim', bin+f}
  end

  def caveats; <<-EOS.undent
    MacVim.app installed to:
      #{prefix}

    To link the application to a normal Mac OS X location:
        brew linkapps
    or:
        ln -s #{prefix}/MacVim.app /Applications
    EOS
  end
end

