require 'formula'

class Plantuml <Formula
  url 'http://downloads.sourceforge.net/project/plantuml/plantuml.jar'
  homepage 'http://plantuml.sourceforge.net/'
  md5 'f3adb5d1802a3574cac89da69ec56c3a'
  version '1.0.7691'

  def jar
    'plantuml.jar'
  end

  def script
<<-EOS
#!/bin/sh
## Runs plantuml

PLANTUML=$(brew --cellar)/#{name}/#{version}/#{jar}

java -jar $PLANTUML "$@"
EOS
  end

  def install
    prefix.install jar
    (bin+'plantuml').write script
  end
end
