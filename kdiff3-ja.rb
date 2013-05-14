require 'formula'

class Kdiff3Ja < Formula
  homepage 'http://kdiff3.sourceforge.net/'
  url 'git://git.code.sf.net/p/kdiff3/code', :revision => '4d116d1cb7e5ca0ed69a4c8e272253198bfbbb91'
  version '0.9.97'
  # sha1 '1f2828c4b287b905bac64992b46a3e9231319547'

  depends_on 'qt'

  option "with-icon", "make with custom icon"

  def patches
    DATA
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
      prefix.install "kdiff3.app"
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

__END__
diff --git a/kdiff3/src-QT4/kdiff3.pro b/kdiff3/src-QT4/kdiff3.pro
index 84ddf47..9aaeeba 100644
--- a/kdiff3/src-QT4/kdiff3.pro
+++ b/kdiff3/src-QT4/kdiff3.pro
@@ -72,3 +72,4 @@ unix {
   target.path = /usr/local/bin
   INSTALLS += target
 }
+ICON = kdiff3.icns
diff --git a/kdiff3/src-QT4/mergeresultwindow.cpp b/kdiff3/src-QT4/mergeresultwindow.cpp
index bd160a7..d8a35b3 100644
--- a/kdiff3/src-QT4/mergeresultwindow.cpp
+++ b/kdiff3/src-QT4/mergeresultwindow.cpp
@@ -1719,6 +1719,29 @@ QVector<QTextLayout::FormatRange> MergeResultWindow::getTextLayoutForLine(int li
    return selectionFormat;
 }
 
+/**
+ * Test if the given character occupies double spaces.
+ *
+ * Returns true for characters in the East Asian Wide (W) or East Asian
+ * FullWidth (F) category as defined in Unicode Technical Report #11.
+ *
+ * This function is borrowed from konsole_wcwidth() of Konsole.
+ */
+static bool isEastAsianFullWidth(QChar c)
+{
+   ushort ucs = c.unicode();
+   return (ucs >= 0x1100 &&
+           (ucs <= 0x115f ||                    // Hangul Jamo init. consonants
+            (ucs >= 0x2e80 && ucs <= 0xa4cf && (ucs & ~0x0011) != 0x300a &&
+             ucs != 0x303f) ||                  // CJK ... Yi
+            (ucs >= 0xac00 && ucs <= 0xd7a3) || // Hangul Syllables
+            (ucs >= 0xf900 && ucs <= 0xfaff) || // CJK Compatibility Ideographs
+            (ucs >= 0xfe30 && ucs <= 0xfe6f) || // CJK Compatibility Forms
+            (ucs >= 0xff00 && ucs <= 0xff5f) || // Fullwidth Forms
+            (ucs >= 0xffe0 && ucs <= 0xffe6) || // do not compare UINT16 with 0x20000
+            (ucs >= 0x300a && ucs <= 0x300b)));  // Specal character 《 and 》(Unicode Standard Annex #11)
+}
+
 void MergeResultWindow::writeLine(
    MyPainter& p, int line, const QString& str,
    int srcSelect, e_MergeDetails mergeDetails, int rangeMark, bool bUserModified, bool bLineRemoved, bool bWhiteSpaceConflict
@@ -1760,7 +1783,7 @@ void MergeResultWindow::writeLine(
       int size = str.length();
       for ( int i=0; i<size; ++i )
       {
-         int spaces = 1;
+         int spaces = (isEastAsianFullWidth(str[i])) ? 2 : 1;
          if ( str[i]=='\t' )
          {
             spaces = tabber( outPos, m_pOptions->m_tabSize );
diff --git a/kdiff3/src-QT4/optiondialog.cpp b/kdiff3/src-QT4/optiondialog.cpp
index 20a3fb6..1b5d41c 100644
--- a/kdiff3/src-QT4/optiondialog.cpp
+++ b/kdiff3/src-QT4/optiondialog.cpp
@@ -885,6 +885,14 @@ void OptionDialog::setupDiffPage( void )
       );
    ++line;
 
+   OptionCheckBox* pIgnoreEncodingWarnMsgBC = new OptionCheckBox( i18n("Ignore Encoding Warn Message"), false, "IgnoreEncodingWarnMessage", &m_options.m_bIgnoreEncodingWarnMsg, page, this );
+   gbox->addWidget( pIgnoreEncodingWarnMsgBC, line, 0, 1, 2 );
+   pDiff3AlignBC->setToolTip( i18n(
+      "Ignore encoding warn dialog.\n"
+      "(Default is off.)")
+      );
+   ++line;
+
    topLayout->addStretch(10);
 }
 
diff --git a/kdiff3/src-QT4/options.h b/kdiff3/src-QT4/options.h
index e0fb850..43eac76 100644
--- a/kdiff3/src-QT4/options.h
+++ b/kdiff3/src-QT4/options.h
@@ -120,6 +120,7 @@ public:
 
     QStringList m_recentOutputFiles;
 
+	bool   m_bIgnoreEncodingWarnMsg;
     // Directory Merge options
     bool m_bDmSyncMode;
     bool m_bDmRecursiveDirs;
diff --git a/kdiff3/src-QT4/pdiff.cpp b/kdiff3/src-QT4/pdiff.cpp
index a10e4e0..6fd8113 100644
--- a/kdiff3/src-QT4/pdiff.cpp
+++ b/kdiff3/src-QT4/pdiff.cpp
@@ -459,13 +459,15 @@ void KDiff3App::init( bool bAuto, TotalDiffStatus* pTotalDiffStatus, bool bLoadF
             files += files.isEmpty() ? "B" : ", B";
          if ( m_sd3.isIncompleteConversion() )
             files += files.isEmpty() ? "C" : ", C";
-            
-         KMessageBox::information( this, i18n(
-            "Some input characters could not be converted to valid unicode.\n"
-            "You might be using the wrong codec. (e.g. UTF-8 for non UTF-8 files).\n"
-            "Don't save the result if unsure. Continue at your own risk.\n"
-            "Affected input files are in %1.").arg(files) );
-      }
+
+         if (! m_pOptions->m_bIgnoreEncodingWarnMsg) {
+           KMessageBox::information( this, i18n(
+              "Some input characters could not be converted to valid unicode.\n"
+              "You might be using the wrong codec. (e.g. UTF-8 for non UTF-8 files).\n"
+              "Don't save the result if unsure. Continue at your own risk.\n"
+              "Affected input files are in %1.").arg(files) );
+         }
+       }
    }
 
    QTimer::singleShot( 10, this, SLOT(slotAfterFirstPaint()) );
