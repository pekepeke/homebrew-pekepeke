require 'formula'

class VimRCustom < Formula
  homepage 'http://vimr.org/'
  url 'https://github.com/qvacua/vimr.git'
  version '0.15-17'
  sha1 'cbce51ae5a89e50e9d0c17e0a81139a463274202'

  depends_on 'lua' => :optional
  depends_on 'luajit' => :optional

  depends_on :xcode # For xcodebuild.

  def patches
  end

  def macvim_patches
    {
      :p1 => [
        'https://bitbucket.org/koron/vim-kaoriya-patches/raw/6658116d59073a4471a83fea41a0791718773a96/X010-autoload_cache.diff',
        'https://gist.github.com/Shougo/5654189/raw',
      ]
    }
  end

  def install
    arch = MacOS.prefer_64_bit? ? 'x86_64' : 'i386'
    ENV['ARCHFLAGS'] = "-arch #{arch}"

    ENV.clang if MacOS.version >= :mountain_lion

    ENV.remove_macosxsdk
    ENV.macosxsdk '10.7'
    ENV.append 'MACOSX_DEPLOYMENT_TARGET', '10.7'
    ENV.append 'CFLAGS', '-mmacosx-version-min=10.7'
    ENV.append 'LDFLAGS', '-mmacosx-version-min=10.7 -headerpad_max_install_names'
    ENV.append 'vi_cv_path_perl', '/usr/bin/perl'
    ENV.append 'vi_cv_path_python', '/usr/bin/python'
    ENV.append 'vi_cv_path_python3', '/usr/bin/python3'
    ENV.append 'vi_cv_path_ruby', '/usr/bin/ruby'

    args = %W[
      --with-features=huge
      --with-tlib=ncurses
      --enable-multibyte
      --enable-netbeans
      --enable-cscope
      --with-macarchs=#{arch}
      --enable-perlinterp=dynamic
      --enable-pythoninterp=dynamic
      --enable-python3interp=dynamic
      --enable-rubyinterp=dynamic
    ]

    lua = nil
    with_lua = false
    if build.include? 'with-luajit'
      args << "--with-luajit"
      lua = Formula.factory('luajit')
      with_lua = true
    elsif build.include? "--with-lua"
      lua = Formula.factory('lua')
      with_lua = true
    end

    if with_lua
      args << "--enable-luainterp"
      args << "--with-lua-prefix=#{HOMEBREW_PREFIX}"
    end

    # if build.include? "with-python3"
    #   args << "--enable-python3interp"
    # end

    # TODO : fixes pod command
    if File.executable? "#{ENV["HOME"]}/.rbenv/shims/pod"
      system "#{ENV["HOME"]}/.rbenv/shims/pod install"
    else
      system "pod install"
    end

    patches =  macvim_patches[:p1]
    patches.each {|url|
      # TODO
      system "curl -L \"#{url}\" | patch -p1 -d macvim"
    }

    Dir.chdir('macvim/src') {

      system "./configure", *args
      system "make"
    }

    system "xcodebuild -workspace VimR.xcworkspace -configuration Release -scheme VimR -derivedDataPath ./build clean build"

    prefix.install "build/Build/Products/Release/VimR.app"
    # inreplace "src/MacVim/mvim", /^# VIM_APP_DIR=\/Applications$/,
    #                              "VIM_APP_DIR=#{prefix}"
    app = prefix + 'VimR.app/Contents'
    macos = app + 'MacOS'

    # cp "#{HOMEBREW_PREFIX}/bin/ctags", macos

    libs = [
    ]
    # FIXME : detect linked version
    libs << "#{HOMEBREW_PREFIX}/lib/lib#{lua.name}.#{lua.installed_version}.dylib" \
      if lua && lua.name == "lua"

    libs << "#{HOMEBREW_PREFIX}/lib/lib#{lua.name}-5.1.#{lua.installed_version}.dylib" \
      if lua && lua.name == "luajit"

    libs.each do |lib|
      newname = "@executable_path/../Frameworks/#{File.basename(lib)}"
      system "install_name_tool -change #{lib} #{newname} #{macos + 'VimR'}"
      cp lib, app + 'Frameworks'
    end

    # bin.install "src/MacVim/mvim"

    # Create MacVim vimdiff, view, ex equivalents
    # executables = %w[mvimdiff mview mvimex gvim gvimdiff gview gvimex]
    # executables += %w[vi vim vimdiff view vimex] if build.include? "override-system-vim"
    # executables.each {|f| ln_s bin+'mvim', bin+f}
  end

  def caveats; <<-EOS.undent
    VimR.app installed to:
      #{prefix}

    To link the application to a normal Mac OS X location:
        brew linkapps
    or:
        ln -s #{prefix}/VimR.app /Applications
    EOS
  end

end
