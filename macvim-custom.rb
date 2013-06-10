require 'formula'

class MacvimCustom < Formula
  homepage 'http://code.google.com/p/macvim/'
  url 'https://github.com/b4winckler/macvim.git'
  # version '7.3.1115' # patch failed
  # version '7.3.1100' # too slow
  version '7.3.1148'
  sha1 '3e20bda2432e694ba89d97652da12f1d18438f19'

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
    {'p0' => (1149..patch_level).map { |i| 
        'ftp://ftp.vim.org/pub/vim/patches/7.3/7.3.%03d' % i 
      },
      'p1' => DATA
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

__END__
diff --git a/src/auto/configure b/src/auto/configure
index 12ba915..4446d68 100755
--- a/src/auto/configure
+++ b/src/auto/configure
@@ -675,6 +675,8 @@ QUOTESED
 dovimdiff
 dogvimdiff
 compiledby
+vi_cv_path_plain_lua
+vi_cv_path_luajit
 vi_cv_path_lua
 LUA_SRC
 LUA_OBJ
@@ -1396,6 +1398,7 @@ Optional Packages:
   --with-features=TYPE    tiny, small, normal, big or huge (default: normal)
   --with-compiledby=NAME  name to show in :version message
   --with-lua-prefix=PFX   Prefix where Lua is installed.
+  --with-luajit           Link with LuaJIT instead of Lua.
   --with-plthome=PLTHOME   Use PLTHOME.
   --with-python-config-dir=PATH  Python's config directory
   --with-python3-config-dir=PATH  Python's config directory
@@ -4750,18 +4753,95 @@ echo "${ECHO_T}not set, default to /usr" >&6; }
     fi
   fi
 
+  { $as_echo "$as_me:${as_lineno-$LINENO}: checking --with-luajit" >&5
+$as_echo_n "checking --with-luajit... " >&6; }
+
+# Check whether --with-luajit was given.
+if test "${with_luajit+set}" = set; then :
+  withval=$with_luajit; vi_cv_with_luajit="$withval"
+else
+  vi_cv_with_luajit="no"
+fi
+
+  { $as_echo "$as_me:${as_lineno-$LINENO}: result: $vi_cv_with_luajit" >&5
+$as_echo "$vi_cv_with_luajit" >&6; }
+
   LUA_INC=
   if test "X$vi_cv_path_lua_pfx" != "X"; then
-        # Extract the first word of "lua", so it can be a program name with args.
+    if test "x$vi_cv_with_luajit" != "xno"; then
+            # Extract the first word of "luajit", so it can be a program name with args.
+set dummy luajit; ac_word=$2
+{ $as_echo "$as_me:${as_lineno-$LINENO}: checking for $ac_word" >&5
+$as_echo_n "checking for $ac_word... " >&6; }
+if test "${ac_cv_path_vi_cv_path_luajit+set}" = set; then :
+  $as_echo_n "(cached) " >&6
+else
+  case $vi_cv_path_luajit in
+  [\\/]* | ?:[\\/]*)
+  ac_cv_path_vi_cv_path_luajit="$vi_cv_path_luajit" # Let the user override the test with a path.
+  ;;
+  *)
+  as_save_IFS=$IFS; IFS=$PATH_SEPARATOR
+for as_dir in $PATH
+do
+  IFS=$as_save_IFS
+  test -z "$as_dir" && as_dir=.
+    for ac_exec_ext in '' $ac_executable_extensions; do
+  if { test -f "$as_dir/$ac_word$ac_exec_ext" && $as_test_x "$as_dir/$ac_word$ac_exec_ext"; }; then
+    ac_cv_path_vi_cv_path_luajit="$as_dir/$ac_word$ac_exec_ext"
+    $as_echo "$as_me:${as_lineno-$LINENO}: found $as_dir/$ac_word$ac_exec_ext" >&5
+    break 2
+  fi
+done
+  done
+IFS=$as_save_IFS
+
+  ;;
+esac
+fi
+vi_cv_path_luajit=$ac_cv_path_vi_cv_path_luajit
+if test -n "$vi_cv_path_luajit"; then
+  { $as_echo "$as_me:${as_lineno-$LINENO}: result: $vi_cv_path_luajit" >&5
+$as_echo "$vi_cv_path_luajit" >&6; }
+else
+  { $as_echo "$as_me:${as_lineno-$LINENO}: result: no" >&5
+$as_echo "no" >&6; }
+fi
+
+
+      if test "X$vi_cv_path_luajit" != "X"; then
+		{ $as_echo "$as_me:${as_lineno-$LINENO}: checking LuaJIT version" >&5
+$as_echo_n "checking LuaJIT version... " >&6; }
+if test "${vi_cv_version_luajit+set}" = set; then :
+  $as_echo_n "(cached) " >&6
+else
+   vi_cv_version_luajit=`${vi_cv_path_luajit} -v | sed 's/LuaJIT \([0-9.]\+\)\.[0-9] .*/\1/'`
+fi
+{ $as_echo "$as_me:${as_lineno-$LINENO}: result: $vi_cv_version_luajit" >&5
+$as_echo "$vi_cv_version_luajit" >&6; }
+	{ $as_echo "$as_me:${as_lineno-$LINENO}: checking Lua version of LuaJIT" >&5
+$as_echo_n "checking Lua version of LuaJIT... " >&6; }
+if test "${vi_cv_version_lua_luajit+set}" = set; then :
+  $as_echo_n "(cached) " >&6
+else
+   vi_cv_version_lua_luajit=`${vi_cv_path_luajit} -e "print(_VERSION)" | sed 's/.* //'`
+fi
+{ $as_echo "$as_me:${as_lineno-$LINENO}: result: $vi_cv_version_lua_luajit" >&5
+$as_echo "$vi_cv_version_lua_luajit" >&6; }
+	vi_cv_path_lua="$vi_cv_path_luajit"
+	vi_cv_version_lua="$vi_cv_version_lua_luajit"
+      fi
+    else
+            # Extract the first word of "lua", so it can be a program name with args.
 set dummy lua; ac_word=$2
-{ echo "$as_me:$LINENO: checking for $ac_word" >&5
-echo $ECHO_N "checking for $ac_word... $ECHO_C" >&6; }
-if test "${ac_cv_path_vi_cv_path_lua+set}" = set; then
-  echo $ECHO_N "(cached) $ECHO_C" >&6
+{ $as_echo "$as_me:${as_lineno-$LINENO}: checking for $ac_word" >&5
+$as_echo_n "checking for $ac_word... " >&6; }
+if test "${ac_cv_path_vi_cv_path_plain_lua+set}" = set; then :
+  $as_echo_n "(cached) " >&6
 else
-  case $vi_cv_path_lua in
+  case $vi_cv_path_plain_lua in
   [\\/]* | ?:[\\/]*)
-  ac_cv_path_vi_cv_path_lua="$vi_cv_path_lua" # Let the user override the test with a path.
+  ac_cv_path_vi_cv_path_plain_lua="$vi_cv_path_plain_lua" # Let the user override the test with a path.
   ;;
   *)
   as_save_IFS=$IFS; IFS=$PATH_SEPARATOR
@@ -4769,111 +4849,144 @@ for as_dir in $PATH
 do
   IFS=$as_save_IFS
   test -z "$as_dir" && as_dir=.
-  for ac_exec_ext in '' $ac_executable_extensions; do
+    for ac_exec_ext in '' $ac_executable_extensions; do
   if { test -f "$as_dir/$ac_word$ac_exec_ext" && $as_test_x "$as_dir/$ac_word$ac_exec_ext"; }; then
-    ac_cv_path_vi_cv_path_lua="$as_dir/$ac_word$ac_exec_ext"
-    echo "$as_me:$LINENO: found $as_dir/$ac_word$ac_exec_ext" >&5
+    ac_cv_path_vi_cv_path_plain_lua="$as_dir/$ac_word$ac_exec_ext"
+    $as_echo "$as_me:${as_lineno-$LINENO}: found $as_dir/$ac_word$ac_exec_ext" >&5
     break 2
   fi
 done
-done
+  done
 IFS=$as_save_IFS
 
   ;;
 esac
 fi
-vi_cv_path_lua=$ac_cv_path_vi_cv_path_lua
-if test -n "$vi_cv_path_lua"; then
-  { echo "$as_me:$LINENO: result: $vi_cv_path_lua" >&5
-echo "${ECHO_T}$vi_cv_path_lua" >&6; }
+vi_cv_path_plain_lua=$ac_cv_path_vi_cv_path_plain_lua
+if test -n "$vi_cv_path_plain_lua"; then
+  { $as_echo "$as_me:${as_lineno-$LINENO}: result: $vi_cv_path_plain_lua" >&5
+$as_echo "$vi_cv_path_plain_lua" >&6; }
 else
-  { echo "$as_me:$LINENO: result: no" >&5
-echo "${ECHO_T}no" >&6; }
+  { $as_echo "$as_me:${as_lineno-$LINENO}: result: no" >&5
+$as_echo "no" >&6; }
 fi
 
 
-    if test "X$vi_cv_path_lua" != "X"; then
-            { echo "$as_me:$LINENO: checking Lua version" >&5
-echo $ECHO_N "checking Lua version... $ECHO_C" >&6; }
-if test "${vi_cv_version_lua+set}" = set; then
-  echo $ECHO_N "(cached) $ECHO_C" >&6
+      if test "X$vi_cv_path_plain_lua" != "X"; then
+		{ $as_echo "$as_me:${as_lineno-$LINENO}: checking Lua version" >&5
+$as_echo_n "checking Lua version... " >&6; }
+if test "${vi_cv_version_plain_lua+set}" = set; then :
+  $as_echo_n "(cached) " >&6
 else
-   vi_cv_version_lua=`${vi_cv_path_lua} -e "print(_VERSION)" | sed 's/.* //'`
+   vi_cv_version_plain_lua=`${vi_cv_path_plain_lua} -e "print(_VERSION)" | sed 's/.* //'`
 fi
-{ echo "$as_me:$LINENO: result: $vi_cv_version_lua" >&5
-echo "${ECHO_T}$vi_cv_version_lua" >&6; }
+{ $as_echo "$as_me:${as_lineno-$LINENO}: result: $vi_cv_version_plain_lua" >&5
+$as_echo "$vi_cv_version_plain_lua" >&6; }
+      fi
+      vi_cv_path_lua="$vi_cv_path_plain_lua"
+      vi_cv_version_lua="$vi_cv_version_plain_lua"
     fi
-    { echo "$as_me:$LINENO: checking if lua.h can be found in $vi_cv_path_lua_pfx/include" >&5
-echo $ECHO_N "checking if lua.h can be found in $vi_cv_path_lua_pfx/include... $ECHO_C" >&6; }
-    if test -f $vi_cv_path_lua_pfx/include/lua.h; then
-      { echo "$as_me:$LINENO: result: yes" >&5
-echo "${ECHO_T}yes" >&6; }
-    else
-      { echo "$as_me:$LINENO: result: no" >&5
-echo "${ECHO_T}no" >&6; }
-      { echo "$as_me:$LINENO: checking if lua.h can be found in $vi_cv_path_lua_pfx/include/lua$vi_cv_version_lua" >&5
-echo $ECHO_N "checking if lua.h can be found in $vi_cv_path_lua_pfx/include/lua$vi_cv_version_lua... $ECHO_C" >&6; }
-      if test -f $vi_cv_path_lua_pfx/include/lua$vi_cv_version_lua/lua.h; then
-        { echo "$as_me:$LINENO: result: yes" >&5
-echo "${ECHO_T}yes" >&6; }
-        LUA_INC=/lua$vi_cv_version_lua
+    if test "x$vi_cv_with_luajit" != "xno" && test "X$vi_cv_version_luajit" != "X"; then
+      { $as_echo "$as_me:${as_lineno-$LINENO}: checking if lua.h can be found in $vi_cv_path_lua_pfx/include/luajit-$vi_cv_version_luajit" >&5
+$as_echo_n "checking if lua.h can be found in $vi_cv_path_lua_pfx/include/luajit-$vi_cv_version_luajit... " >&6; }
+      if test -f $vi_cv_path_lua_pfx/include/luajit-$vi_cv_version_luajit/lua.h; then
+	{ $as_echo "$as_me:${as_lineno-$LINENO}: result: yes" >&5
+$as_echo "yes" >&6; }
+	LUA_INC=/luajit-$vi_cv_version_luajit
+      fi
+    fi
+    if test "X$LUA_INC" = "X"; then
+      { $as_echo "$as_me:${as_lineno-$LINENO}: checking if lua.h can be found in $vi_cv_path_lua_pfx/include" >&5
+$as_echo_n "checking if lua.h can be found in $vi_cv_path_lua_pfx/include... " >&6; }
+      if test -f $vi_cv_path_lua_pfx/include/lua.h; then
+	{ $as_echo "$as_me:${as_lineno-$LINENO}: result: yes" >&5
+$as_echo "yes" >&6; }
       else
-        { echo "$as_me:$LINENO: result: no" >&5
-echo "${ECHO_T}no" >&6; }
-        vi_cv_path_lua_pfx=
+	{ $as_echo "$as_me:${as_lineno-$LINENO}: result: no" >&5
+$as_echo "no" >&6; }
+	{ $as_echo "$as_me:${as_lineno-$LINENO}: checking if lua.h can be found in $vi_cv_path_lua_pfx/include/lua$vi_cv_version_lua" >&5
+$as_echo_n "checking if lua.h can be found in $vi_cv_path_lua_pfx/include/lua$vi_cv_version_lua... " >&6; }
+	if test -f $vi_cv_path_lua_pfx/include/lua$vi_cv_version_lua/lua.h; then
+	  { $as_echo "$as_me:${as_lineno-$LINENO}: result: yes" >&5
+$as_echo "yes" >&6; }
+	  LUA_INC=/lua$vi_cv_version_lua
+	else
+	  { $as_echo "$as_me:${as_lineno-$LINENO}: result: no" >&5
+$as_echo "no" >&6; }
+	  vi_cv_path_lua_pfx=
+	fi
       fi
     fi
   fi
 
   if test "X$vi_cv_path_lua_pfx" != "X"; then
-    if test "X$LUA_INC" != "X"; then
-            LUA_LIBS="-L${vi_cv_path_lua_pfx}/lib -llua$vi_cv_version_lua"
+    if test "x$vi_cv_with_luajit" != "xno"; then
+      multiarch=`dpkg-architecture -qDEB_HOST_MULTIARCH 2> /dev/null`
+      if test "X$multiarch" != "X"; then
+	lib_multiarch="lib/${multiarch}"
+      else
+	lib_multiarch="lib"
+      fi
+      LUA_LIBS="-L${vi_cv_path_lua_pfx}/${lib_multiarch} -lluajit-$vi_cv_version_lua"
     else
-      LUA_LIBS="-L${vi_cv_path_lua_pfx}/lib -llua"
+      if test "X$LUA_INC" != "X"; then
+		LUA_LIBS="-L${vi_cv_path_lua_pfx}/lib -llua$vi_cv_version_lua"
+      else
+	LUA_LIBS="-L${vi_cv_path_lua_pfx}/lib -llua"
+      fi
     fi
     LUA_CFLAGS="-I${vi_cv_path_lua_pfx}/include${LUA_INC}"
     LUA_SRC="if_lua.c"
     LUA_OBJ="objects/if_lua.o"
     LUA_PRO="if_lua.pro"
-    cat >>confdefs.h <<\_ACEOF
-#define FEAT_LUA 1
-_ACEOF
+    $as_echo "#define FEAT_LUA 1" >>confdefs.h
 
     if test "$enable_luainterp" = "dynamic"; then
+      if test "x$vi_cv_with_luajit" != "xno"; then
+	luajit="jit"
+      fi
       if test -f "${vi_cv_path_lua_pfx}/bin/cyglua-${vi_cv_version_lua}.dll"; then
 	vi_cv_dll_name_lua="cyglua-${vi_cv_version_lua}.dll"
       else
-	multiarch=`dpkg-architecture -qDEB_HOST_MULTIARCH 2> /dev/null`
-	if test "X$multiarch" != "X"; then
-	  lib_multiarch="lib/${multiarch}"
+	if test "x$MACOSX" = "xyes"; then
+	  ext="dylib"
+	  indexes=""
+	else
+	  ext="so"
+	  indexes=".0 .1 .2 .3 .4 .5 .6 .7 .8 .9"
+	  multiarch=`dpkg-architecture -qDEB_HOST_MULTIARCH 2> /dev/null`
+	  if test "X$multiarch" != "X"; then
+	    lib_multiarch="lib/${multiarch}"
+	  fi
 	fi
 			for subdir in "${lib_multiarch}" lib64 lib; do
 	  if test -z "$subdir"; then
 	    continue
 	  fi
-	  for sover in "${vi_cv_version_lua}.so" "-${vi_cv_version_lua}.so" ".so.${vi_cv_version_lua}"; do
-	    for i in .0 .1 .2 .3 .4 .5 .6 .7 .8 .9 ""; do
-	      if test -f "${vi_cv_path_lua_pfx}/${subdir}/liblua${sover}$i"; then
+	  for sover in "${vi_cv_version_lua}.${ext}" "-${vi_cv_version_lua}.${ext}" \
+	    ".${vi_cv_version_lua}.${ext}" ".${ext}.${vi_cv_version_lua}"; do
+	    for i in $indexes ""; do
+	      if test -f "${vi_cv_path_lua_pfx}/${subdir}/liblua${luajit}${sover}$i"; then
 		sover2="$i"
 		break 3
 	      fi
 	    done
 	  done
 	done
-	vi_cv_dll_name_lua="liblua${sover}$sover2"
+	vi_cv_dll_name_lua="liblua${luajit}${sover}$sover2"
       fi
-      cat >>confdefs.h <<\_ACEOF
-#define DYNAMIC_LUA 1
-_ACEOF
+      $as_echo "#define DYNAMIC_LUA 1" >>confdefs.h
 
       LUA_LIBS=""
       LUA_CFLAGS="-DDYNAMIC_LUA_DLL=\\\"${vi_cv_dll_name_lua}\\\" $LUA_CFLAGS"
     fi
+    if test "x$MACOSX" = "xyes" && test "x$vi_cv_with_luajit" != "xno" && \
+       test "`(uname -m) 2>/dev/null`" = "x86_64"; then
+            LUA_LIBS="-pagezero_size 10000 -image_base 100000000 $LUA_LIBS"
+    fi
   fi
   if test "$fail_if_missing" = "yes" -a -z "$LUA_SRC"; then
-    { { echo "$as_me:$LINENO: error: could not configure lua" >&5
-echo "$as_me: error: could not configure lua" >&2;}
-   { (exit 1); exit 1; }; }
+    as_fn_error "could not configure lua" "$LINENO" 5
   fi
 
 
diff --git a/src/configure b/src/configure
index 26f1b4e..3d6209d 100755
--- a/src/configure
+++ b/src/configure
@@ -684,6 +684,8 @@ LUA_LIBS
 LUA_PRO
 LUA_OBJ
 LUA_SRC
+vi_cv_path_plain_lua
+vi_cv_path_luajit
 vi_cv_path_lua
 compiledby
 dogvimdiff
@@ -769,6 +771,7 @@ enable_xsmp
 enable_xsmp_interact
 enable_luainterp
 with_lua_prefix
+with_luajit
 enable_mzschemeinterp
 with_plthome
 enable_perlinterp
@@ -1485,6 +1488,7 @@ Optional Packages:
   --with-features=TYPE    tiny, small, normal, big or huge (default: normal)
   --with-compiledby=NAME  name to show in :version message
   --with-lua-prefix=PFX   Prefix where Lua is installed.
+  --with-luajit           Link with LuaJIT instead of Lua.
   --with-plthome=PLTHOME   Use PLTHOME.
   --with-python-config-dir=PATH  Python's config directory
   --with-python3-config-dir=PATH  Python's config directory
@@ -4694,18 +4698,95 @@ $as_echo "not set, default to /usr" >&6; }
     fi
   fi
 
+  { $as_echo "$as_me:${as_lineno-$LINENO}: checking --with-luajit" >&5
+$as_echo_n "checking --with-luajit... " >&6; }
+
+# Check whether --with-luajit was given.
+if test "${with_luajit+set}" = set; then :
+  withval=$with_luajit; vi_cv_with_luajit="$withval"
+else
+  vi_cv_with_luajit="no"
+fi
+
+  { $as_echo "$as_me:${as_lineno-$LINENO}: result: $vi_cv_with_luajit" >&5
+$as_echo "$vi_cv_with_luajit" >&6; }
+
   LUA_INC=
   if test "X$vi_cv_path_lua_pfx" != "X"; then
-        # Extract the first word of "lua", so it can be a program name with args.
+    if test "x$vi_cv_with_luajit" != "xno"; then
+            # Extract the first word of "luajit", so it can be a program name with args.
+set dummy luajit; ac_word=$2
+{ $as_echo "$as_me:${as_lineno-$LINENO}: checking for $ac_word" >&5
+$as_echo_n "checking for $ac_word... " >&6; }
+if test "${ac_cv_path_vi_cv_path_luajit+set}" = set; then :
+  $as_echo_n "(cached) " >&6
+else
+  case $vi_cv_path_luajit in
+  [\\/]* | ?:[\\/]*)
+  ac_cv_path_vi_cv_path_luajit="$vi_cv_path_luajit" # Let the user override the test with a path.
+  ;;
+  *)
+  as_save_IFS=$IFS; IFS=$PATH_SEPARATOR
+for as_dir in $PATH
+do
+  IFS=$as_save_IFS
+  test -z "$as_dir" && as_dir=.
+    for ac_exec_ext in '' $ac_executable_extensions; do
+  if { test -f "$as_dir/$ac_word$ac_exec_ext" && $as_test_x "$as_dir/$ac_word$ac_exec_ext"; }; then
+    ac_cv_path_vi_cv_path_luajit="$as_dir/$ac_word$ac_exec_ext"
+    $as_echo "$as_me:${as_lineno-$LINENO}: found $as_dir/$ac_word$ac_exec_ext" >&5
+    break 2
+  fi
+done
+  done
+IFS=$as_save_IFS
+
+  ;;
+esac
+fi
+vi_cv_path_luajit=$ac_cv_path_vi_cv_path_luajit
+if test -n "$vi_cv_path_luajit"; then
+  { $as_echo "$as_me:${as_lineno-$LINENO}: result: $vi_cv_path_luajit" >&5
+$as_echo "$vi_cv_path_luajit" >&6; }
+else
+  { $as_echo "$as_me:${as_lineno-$LINENO}: result: no" >&5
+$as_echo "no" >&6; }
+fi
+
+
+      if test "X$vi_cv_path_luajit" != "X"; then
+		{ $as_echo "$as_me:${as_lineno-$LINENO}: checking LuaJIT version" >&5
+$as_echo_n "checking LuaJIT version... " >&6; }
+if test "${vi_cv_version_luajit+set}" = set; then :
+  $as_echo_n "(cached) " >&6
+else
+   vi_cv_version_luajit=`${vi_cv_path_luajit} -v | sed 's/LuaJIT \([0-9.]\+\)\.[0-9] .*/\1/'`
+fi
+{ $as_echo "$as_me:${as_lineno-$LINENO}: result: $vi_cv_version_luajit" >&5
+$as_echo "$vi_cv_version_luajit" >&6; }
+	{ $as_echo "$as_me:${as_lineno-$LINENO}: checking Lua version of LuaJIT" >&5
+$as_echo_n "checking Lua version of LuaJIT... " >&6; }
+if test "${vi_cv_version_lua_luajit+set}" = set; then :
+  $as_echo_n "(cached) " >&6
+else
+   vi_cv_version_lua_luajit=`${vi_cv_path_luajit} -e "print(_VERSION)" | sed 's/.* //'`
+fi
+{ $as_echo "$as_me:${as_lineno-$LINENO}: result: $vi_cv_version_lua_luajit" >&5
+$as_echo "$vi_cv_version_lua_luajit" >&6; }
+	vi_cv_path_lua="$vi_cv_path_luajit"
+	vi_cv_version_lua="$vi_cv_version_lua_luajit"
+      fi
+    else
+            # Extract the first word of "lua", so it can be a program name with args.
 set dummy lua; ac_word=$2
 { $as_echo "$as_me:${as_lineno-$LINENO}: checking for $ac_word" >&5
 $as_echo_n "checking for $ac_word... " >&6; }
-if ${ac_cv_path_vi_cv_path_lua+:} false; then :
+if test "${ac_cv_path_vi_cv_path_plain_lua+set}" = set; then :
   $as_echo_n "(cached) " >&6
 else
-  case $vi_cv_path_lua in
+  case $vi_cv_path_plain_lua in
   [\\/]* | ?:[\\/]*)
-  ac_cv_path_vi_cv_path_lua="$vi_cv_path_lua" # Let the user override the test with a path.
+  ac_cv_path_vi_cv_path_plain_lua="$vi_cv_path_plain_lua" # Let the user override the test with a path.
   ;;
   *)
   as_save_IFS=$IFS; IFS=$PATH_SEPARATOR
@@ -4715,7 +4796,7 @@ do
   test -z "$as_dir" && as_dir=.
     for ac_exec_ext in '' $ac_executable_extensions; do
   if { test -f "$as_dir/$ac_word$ac_exec_ext" && $as_test_x "$as_dir/$ac_word$ac_exec_ext"; }; then
-    ac_cv_path_vi_cv_path_lua="$as_dir/$ac_word$ac_exec_ext"
+    ac_cv_path_vi_cv_path_plain_lua="$as_dir/$ac_word$ac_exec_ext"
     $as_echo "$as_me:${as_lineno-$LINENO}: found $as_dir/$ac_word$ac_exec_ext" >&5
     break 2
   fi
@@ -4726,54 +4807,78 @@ IFS=$as_save_IFS
   ;;
 esac
 fi
-vi_cv_path_lua=$ac_cv_path_vi_cv_path_lua
-if test -n "$vi_cv_path_lua"; then
-  { $as_echo "$as_me:${as_lineno-$LINENO}: result: $vi_cv_path_lua" >&5
-$as_echo "$vi_cv_path_lua" >&6; }
+vi_cv_path_plain_lua=$ac_cv_path_vi_cv_path_plain_lua
+if test -n "$vi_cv_path_plain_lua"; then
+  { $as_echo "$as_me:${as_lineno-$LINENO}: result: $vi_cv_path_plain_lua" >&5
+$as_echo "$vi_cv_path_plain_lua" >&6; }
 else
   { $as_echo "$as_me:${as_lineno-$LINENO}: result: no" >&5
 $as_echo "no" >&6; }
 fi
 
 
-    if test "X$vi_cv_path_lua" != "X"; then
-            { $as_echo "$as_me:${as_lineno-$LINENO}: checking Lua version" >&5
+      if test "X$vi_cv_path_plain_lua" != "X"; then
+		{ $as_echo "$as_me:${as_lineno-$LINENO}: checking Lua version" >&5
 $as_echo_n "checking Lua version... " >&6; }
-if ${vi_cv_version_lua+:} false; then :
+if test "${vi_cv_version_plain_lua+set}" = set; then :
   $as_echo_n "(cached) " >&6
 else
-   vi_cv_version_lua=`${vi_cv_path_lua} -e "print(_VERSION)" | sed 's/.* //'`
+   vi_cv_version_plain_lua=`${vi_cv_path_plain_lua} -e "print(_VERSION)" | sed 's/.* //'`
 fi
-{ $as_echo "$as_me:${as_lineno-$LINENO}: result: $vi_cv_version_lua" >&5
-$as_echo "$vi_cv_version_lua" >&6; }
+{ $as_echo "$as_me:${as_lineno-$LINENO}: result: $vi_cv_version_plain_lua" >&5
+$as_echo "$vi_cv_version_plain_lua" >&6; }
+      fi
+      vi_cv_path_lua="$vi_cv_path_plain_lua"
+      vi_cv_version_lua="$vi_cv_version_plain_lua"
     fi
-    { $as_echo "$as_me:${as_lineno-$LINENO}: checking if lua.h can be found in $vi_cv_path_lua_pfx/include" >&5
+    if test "x$vi_cv_with_luajit" != "xno" && test "X$vi_cv_version_luajit" != "X"; then
+      { $as_echo "$as_me:${as_lineno-$LINENO}: checking if lua.h can be found in $vi_cv_path_lua_pfx/include/luajit-$vi_cv_version_luajit" >&5
+$as_echo_n "checking if lua.h can be found in $vi_cv_path_lua_pfx/include/luajit-$vi_cv_version_luajit... " >&6; }
+      if test -f $vi_cv_path_lua_pfx/include/luajit-$vi_cv_version_luajit/lua.h; then
+	{ $as_echo "$as_me:${as_lineno-$LINENO}: result: yes" >&5
+$as_echo "yes" >&6; }
+	LUA_INC=/luajit-$vi_cv_version_luajit
+      fi
+    fi
+    if test "X$LUA_INC" = "X"; then
+      { $as_echo "$as_me:${as_lineno-$LINENO}: checking if lua.h can be found in $vi_cv_path_lua_pfx/include" >&5
 $as_echo_n "checking if lua.h can be found in $vi_cv_path_lua_pfx/include... " >&6; }
-    if test -f $vi_cv_path_lua_pfx/include/lua.h; then
-      { $as_echo "$as_me:${as_lineno-$LINENO}: result: yes" >&5
+      if test -f $vi_cv_path_lua_pfx/include/lua.h; then
+	{ $as_echo "$as_me:${as_lineno-$LINENO}: result: yes" >&5
 $as_echo "yes" >&6; }
-    else
-      { $as_echo "$as_me:${as_lineno-$LINENO}: result: no" >&5
+      else
+	{ $as_echo "$as_me:${as_lineno-$LINENO}: result: no" >&5
 $as_echo "no" >&6; }
-      { $as_echo "$as_me:${as_lineno-$LINENO}: checking if lua.h can be found in $vi_cv_path_lua_pfx/include/lua$vi_cv_version_lua" >&5
+	{ $as_echo "$as_me:${as_lineno-$LINENO}: checking if lua.h can be found in $vi_cv_path_lua_pfx/include/lua$vi_cv_version_lua" >&5
 $as_echo_n "checking if lua.h can be found in $vi_cv_path_lua_pfx/include/lua$vi_cv_version_lua... " >&6; }
-      if test -f $vi_cv_path_lua_pfx/include/lua$vi_cv_version_lua/lua.h; then
-        { $as_echo "$as_me:${as_lineno-$LINENO}: result: yes" >&5
+	if test -f $vi_cv_path_lua_pfx/include/lua$vi_cv_version_lua/lua.h; then
+	  { $as_echo "$as_me:${as_lineno-$LINENO}: result: yes" >&5
 $as_echo "yes" >&6; }
-        LUA_INC=/lua$vi_cv_version_lua
-      else
-        { $as_echo "$as_me:${as_lineno-$LINENO}: result: no" >&5
+	  LUA_INC=/lua$vi_cv_version_lua
+	else
+	  { $as_echo "$as_me:${as_lineno-$LINENO}: result: no" >&5
 $as_echo "no" >&6; }
-        vi_cv_path_lua_pfx=
+	  vi_cv_path_lua_pfx=
+	fi
       fi
     fi
   fi
 
   if test "X$vi_cv_path_lua_pfx" != "X"; then
-    if test "X$LUA_INC" != "X"; then
-            LUA_LIBS="-L${vi_cv_path_lua_pfx}/lib -llua$vi_cv_version_lua"
+    if test "x$vi_cv_with_luajit" != "xno"; then
+      multiarch=`dpkg-architecture -qDEB_HOST_MULTIARCH 2> /dev/null`
+      if test "X$multiarch" != "X"; then
+	lib_multiarch="lib/${multiarch}"
+      else
+	lib_multiarch="lib"
+      fi
+      LUA_LIBS="-L${vi_cv_path_lua_pfx}/${lib_multiarch} -lluajit-$vi_cv_version_lua"
     else
-      LUA_LIBS="-L${vi_cv_path_lua_pfx}/lib -llua"
+      if test "X$LUA_INC" != "X"; then
+		LUA_LIBS="-L${vi_cv_path_lua_pfx}/lib -llua$vi_cv_version_lua"
+      else
+	LUA_LIBS="-L${vi_cv_path_lua_pfx}/lib -llua"
+      fi
     fi
     LUA_CFLAGS="-I${vi_cv_path_lua_pfx}/include${LUA_INC}"
     LUA_SRC="if_lua.c"
@@ -4782,25 +4887,51 @@ $as_echo "no" >&6; }
     $as_echo "#define FEAT_LUA 1" >>confdefs.h
 
     if test "$enable_luainterp" = "dynamic"; then
+      if test "x$vi_cv_with_luajit" != "xno"; then
+	luajit="jit"
+      fi
       if test -f "${vi_cv_path_lua_pfx}/bin/cyglua-${vi_cv_version_lua}.dll"; then
 	vi_cv_dll_name_lua="cyglua-${vi_cv_version_lua}.dll"
       else
-			for i in 0 1 2 3 4 5 6 7 8 9; do
-	  if test -f "${vi_cv_path_lua_pfx}/lib/liblua${vi_cv_version_lua}.so.$i"; then
-	    LUA_SONAME=".$i"
-	    break
+	if test "x$MACOSX" = "xyes"; then
+	  ext="dylib"
+	  indexes=""
+	else
+	  ext="so"
+	  indexes=".0 .1 .2 .3 .4 .5 .6 .7 .8 .9"
+	  multiarch=`dpkg-architecture -qDEB_HOST_MULTIARCH 2> /dev/null`
+	  if test "X$multiarch" != "X"; then
+	    lib_multiarch="lib/${multiarch}"
+	  fi
+	fi
+			for subdir in "${lib_multiarch}" lib64 lib; do
+	  if test -z "$subdir"; then
+	    continue
 	  fi
+	  for sover in "${vi_cv_version_lua}.${ext}" "-${vi_cv_version_lua}.${ext}" \
+	    ".${vi_cv_version_lua}.${ext}" ".${ext}.${vi_cv_version_lua}"; do
+	    for i in $indexes ""; do
+	      if test -f "${vi_cv_path_lua_pfx}/${subdir}/liblua${luajit}${sover}$i"; then
+		sover2="$i"
+		break 3
+	      fi
+	    done
+	  done
 	done
-	vi_cv_dll_name_lua="liblua${vi_cv_version_lua}.so$LUA_SONAME"
+	vi_cv_dll_name_lua="liblua${luajit}${sover}$sover2"
       fi
       $as_echo "#define DYNAMIC_LUA 1" >>confdefs.h
 
       LUA_LIBS=""
       LUA_CFLAGS="-DDYNAMIC_LUA_DLL=\\\"${vi_cv_dll_name_lua}\\\" $LUA_CFLAGS"
     fi
+    if test "x$MACOSX" = "xyes" && test "x$vi_cv_with_luajit" != "xno" && \
+       test "`(uname -m) 2>/dev/null`" = "x86_64"; then
+            LUA_LIBS="-pagezero_size 10000 -image_base 100000000 $LUA_LIBS"
+    fi
   fi
   if test "$fail_if_missing" = "yes" -a -z "$LUA_SRC"; then
-    as_fn_error $? "could not configure lua" "$LINENO" 5
+    as_fn_error "could not configure lua" "$LINENO" 5
   fi
 
 
diff --git a/src/configure.in b/src/configure.in
index e0810d6..8c28344 100644
--- a/src/configure.in
+++ b/src/configure.in
@@ -33,7 +33,7 @@ dnl Check for the flag that fails if stuff are missing.
 AC_MSG_CHECKING(--enable-fail-if-missing argument)
 AC_ARG_ENABLE(fail_if_missing,
 	[  --enable-fail-if-missing    Fail if dependencies on additional features
-     specified on the command line are missing.], 
+     specified on the command line are missing.],
 	[fail_if_missing="yes"],
 	[fail_if_missing="no"])
 AC_MSG_RESULT($fail_if_missing)
@@ -125,7 +125,7 @@ if test "`(uname) 2>/dev/null`" = Darwin; then
   AC_ARG_WITH(developer-dir, [  --with-developer-dir=PATH    use PATH as location for Xcode developer tools],
 	DEVELOPER_DIR="$withval"; AC_MSG_RESULT($DEVELOPER_DIR),
         DEVELOPER_DIR=""; AC_MSG_RESULT(not present))
-  
+
   if test "x$DEVELOPER_DIR" = "x"; then
     AC_PATH_PROG(XCODE_SELECT, xcode-select)
     if test "x$XCODE_SELECT" != "x"; then
@@ -467,15 +467,46 @@ if test "$enable_luainterp" = "yes" -o "$enable_luainterp" = "dynamic"; then
     fi
   fi
 
+  AC_MSG_CHECKING(--with-luajit)
+  AC_ARG_WITH(luajit,
+	[  --with-luajit           Link with LuaJIT instead of Lua.],
+	[vi_cv_with_luajit="$withval"],
+	[vi_cv_with_luajit="no"])
+  AC_MSG_RESULT($vi_cv_with_luajit)
+
   LUA_INC=
   if test "X$vi_cv_path_lua_pfx" != "X"; then
+    if test "x$vi_cv_with_luajit" != "xno"; then
+      dnl -- try to find LuaJIT executable
+      AC_PATH_PROG(vi_cv_path_luajit, luajit)
+      if test "X$vi_cv_path_luajit" != "X"; then
+	dnl -- find LuaJIT version
+	AC_CACHE_CHECK(LuaJIT version, vi_cv_version_luajit,
+	[ vi_cv_version_luajit=`${vi_cv_path_luajit} -v | sed 's/LuaJIT \([[0-9.]]\+\)\.[[0-9]] .*/\1/'` ])
+	AC_CACHE_CHECK(Lua version of LuaJIT, vi_cv_version_lua_luajit,
+	[ vi_cv_version_lua_luajit=`${vi_cv_path_luajit} -e "print(_VERSION)" | sed 's/.* //'` ])
+	vi_cv_path_lua="$vi_cv_path_luajit"
+	vi_cv_version_lua="$vi_cv_version_lua_luajit"
+      fi
+    else
     dnl -- try to find Lua executable
-    AC_PATH_PROG(vi_cv_path_lua, lua)
-    if test "X$vi_cv_path_lua" != "X"; then
+      AC_PATH_PROG(vi_cv_path_plain_lua, lua)
+      if test "X$vi_cv_path_plain_lua" != "X"; then
       dnl -- find Lua version
-      AC_CACHE_CHECK(Lua version, vi_cv_version_lua,
-      [ vi_cv_version_lua=`${vi_cv_path_lua} -e "print(_VERSION)" | sed 's/.* //'` ])
+	AC_CACHE_CHECK(Lua version, vi_cv_version_plain_lua,
+	[ vi_cv_version_plain_lua=`${vi_cv_path_plain_lua} -e "print(_VERSION)" | sed 's/.* //'` ])
+      fi
+      vi_cv_path_lua="$vi_cv_path_plain_lua"
+      vi_cv_version_lua="$vi_cv_version_plain_lua"
     fi
+    if test "x$vi_cv_with_luajit" != "xno" && test "X$vi_cv_version_luajit" != "X"; then
+      AC_MSG_CHECKING(if lua.h can be found in $vi_cv_path_lua_pfx/include/luajit-$vi_cv_version_luajit)
+      if test -f $vi_cv_path_lua_pfx/include/luajit-$vi_cv_version_luajit/lua.h; then
+	AC_MSG_RESULT(yes)
+	LUA_INC=/luajit-$vi_cv_version_luajit
+      fi
+    fi
+    if test "X$LUA_INC" = "X"; then
     AC_MSG_CHECKING(if lua.h can be found in $vi_cv_path_lua_pfx/include)
     if test -f $vi_cv_path_lua_pfx/include/lua.h; then
       AC_MSG_RESULT(yes)
@@ -491,48 +522,75 @@ if test "$enable_luainterp" = "yes" -o "$enable_luainterp" = "dynamic"; then
       fi
     fi
   fi
+  fi
 
   if test "X$vi_cv_path_lua_pfx" != "X"; then
+    if test "x$vi_cv_with_luajit" != "xno"; then
+      multiarch=`dpkg-architecture -qDEB_HOST_MULTIARCH 2> /dev/null`
+      if test "X$multiarch" != "X"; then
+	lib_multiarch="lib/${multiarch}"
+      else
+	lib_multiarch="lib"
+      fi
+      LUA_LIBS="-L${vi_cv_path_lua_pfx}/${lib_multiarch} -lluajit-$vi_cv_version_lua"
+    else
     if test "X$LUA_INC" != "X"; then
       dnl Test alternate location using version
       LUA_LIBS="-L${vi_cv_path_lua_pfx}/lib -llua$vi_cv_version_lua"
     else
       LUA_LIBS="-L${vi_cv_path_lua_pfx}/lib -llua"
     fi
+    fi
     LUA_CFLAGS="-I${vi_cv_path_lua_pfx}/include${LUA_INC}"
     LUA_SRC="if_lua.c"
     LUA_OBJ="objects/if_lua.o"
     LUA_PRO="if_lua.pro"
     AC_DEFINE(FEAT_LUA)
     if test "$enable_luainterp" = "dynamic"; then
+      if test "x$vi_cv_with_luajit" != "xno"; then
+	luajit="jit"
+      fi
       if test -f "${vi_cv_path_lua_pfx}/bin/cyglua-${vi_cv_version_lua}.dll"; then
 	vi_cv_dll_name_lua="cyglua-${vi_cv_version_lua}.dll"
       else
+	if test "x$MACOSX" = "xyes"; then
+	  ext="dylib"
+	  indexes=""
+	else
+	  ext="so"
+	  indexes=".0 .1 .2 .3 .4 .5 .6 .7 .8 .9"
 	multiarch=`dpkg-architecture -qDEB_HOST_MULTIARCH 2> /dev/null`
 	if test "X$multiarch" != "X"; then
 	  lib_multiarch="lib/${multiarch}"
 	fi
+	fi
 	dnl Determine the sover for the current version, but fallback to
 	dnl liblua${vi_cv_version_lua}.so if no sover-versioned file is found.
 	for subdir in "${lib_multiarch}" lib64 lib; do
 	  if test -z "$subdir"; then
 	    continue
 	  fi
-	  for sover in "${vi_cv_version_lua}.so" "-${vi_cv_version_lua}.so" ".so.${vi_cv_version_lua}"; do
-	    for i in .0 .1 .2 .3 .4 .5 .6 .7 .8 .9 ""; do
-	      if test -f "${vi_cv_path_lua_pfx}/${subdir}/liblua${sover}$i"; then
+	  for sover in "${vi_cv_version_lua}.${ext}" "-${vi_cv_version_lua}.${ext}" \
+	    ".${vi_cv_version_lua}.${ext}" ".${ext}.${vi_cv_version_lua}"; do
+	    for i in $indexes ""; do
+	      if test -f "${vi_cv_path_lua_pfx}/${subdir}/liblua${luajit}${sover}$i"; then
 		sover2="$i"
 		break 3
 	      fi
 	    done
 	  done
 	done
-	vi_cv_dll_name_lua="liblua${sover}$sover2"
+	vi_cv_dll_name_lua="liblua${luajit}${sover}$sover2"
       fi
       AC_DEFINE(DYNAMIC_LUA)
       LUA_LIBS=""
       LUA_CFLAGS="-DDYNAMIC_LUA_DLL=\\\"${vi_cv_dll_name_lua}\\\" $LUA_CFLAGS"
     fi
+    if test "x$MACOSX" = "xyes" && test "x$vi_cv_with_luajit" != "xno" && \
+       test "`(uname -m) 2>/dev/null`" = "x86_64"; then
+      dnl OSX/x64 requires these flags. See http://luajit.org/install.html
+      LUA_LIBS="-pagezero_size 10000 -image_base 100000000 $LUA_LIBS"
+    fi
   fi
   if test "$fail_if_missing" = "yes" -a -z "$LUA_SRC"; then
     AC_MSG_ERROR([could not configure lua])
@@ -1099,7 +1157,7 @@ if test "$enable_python3interp" = "yes" -o "$enable_python3interp" = "dynamic";
      if ${vi_cv_path_python3} -c \
          "import sys; sys.exit(${vi_cv_var_python3_version} < 3.2)"
      then
-       vi_cv_var_python3_abiflags=`${vi_cv_path_python3} -c \    
+       vi_cv_var_python3_abiflags=`${vi_cv_path_python3} -c \
          "import sys; print(sys.abiflags)"`
      fi ])
 
@@ -1257,7 +1315,7 @@ AC_SUBST(PYTHON3_SRC)
 AC_SUBST(PYTHON3_OBJ)
 
 dnl if python2.x and python3.x are enabled one can only link in code
-dnl with dlopen(), dlsym(), dlclose() 
+dnl with dlopen(), dlsym(), dlclose()
 if test "$python_ok" = yes && test "$python3_ok" = yes; then
   AC_DEFINE(DYNAMIC_PYTHON)
   AC_DEFINE(DYNAMIC_PYTHON3)
@@ -1883,16 +1941,16 @@ elif test "x$MACOSX" = "xyes" -a "x$with_x" = "xno" ; then
   SKIP_MACVIM=
   case "$enable_gui_canon" in
     no)		AC_MSG_RESULT(no GUI support)
-		SKIP_CARBON=YES 
+		SKIP_CARBON=YES
 		SKIP_MACVIM=YES ;;
     yes|""|auto)	AC_MSG_RESULT(yes/auto - automatic GUI support)
 		SKIP_CARBON=YES ;;
-    carbon)	AC_MSG_RESULT(Carbon GUI support) 
+    carbon)	AC_MSG_RESULT(Carbon GUI support)
 		SKIP_MACVIM=YES ;;
-    macvim)	AC_MSG_RESULT(MacVim GUI support) 
+    macvim)	AC_MSG_RESULT(MacVim GUI support)
 		SKIP_CARBON=YES ;;
     *)		AC_MSG_RESULT([Sorry, $enable_gui GUI is not supported])
-		SKIP_CARBON=YES 
+		SKIP_CARBON=YES
 		SKIP_MACVIM=YES ;;
   esac
 
@@ -2502,8 +2560,8 @@ if test -z "$SKIP_MOTIF"; then
 	xmheader="Xm/Xm.h"
   else
 	xmheader="Xm/Xm.h Xm/XpmP.h Xm/JoinSideT.h Xm/TraitP.h Xm/Manager.h
-  	   Xm/UnhighlightT.h Xm/Notebook.h"  
-  fi    
+  	   Xm/UnhighlightT.h Xm/Notebook.h"
+  fi
   AC_CHECK_HEADERS($xmheader)
 
   if test "x$ac_cv_header_Xm_XpmP_h" = "xyes"; then
@@ -2897,7 +2955,7 @@ main()
 	AC_MSG_ERROR(failed to compile test program.)
       ])
     ])
-  
+
   if test "x$vim_cv_tgent" = "xzero" ; then
     AC_DEFINE(TGETENT_ZERO_ERR, 0)
   fi
@@ -3184,7 +3242,7 @@ main() {struct stat st;  exit(stat("configure/", &st) != 0); }
 if test "x$vim_cv_stat_ignores_slash" = "xyes" ; then
   AC_DEFINE(STAT_IGNORES_SLASH)
 fi
-  
+
 dnl Link with iconv for charset translation, if not found without library.
 dnl check for iconv() requires including iconv.h
 dnl Add "-liconv" when possible; Solaris has iconv but use GNU iconv when it

