require 'formula'

class ThePlatinumSearcher < ScriptFileFormula
  homepage 'https://github.com/monochromegane/the_platinum_searcher'
  url 'https://drone.io/github.com/monochromegane/the_platinum_searcher/files/artifacts/bin/darwin_amd64/pt', :using => :curl
  # since the version stated in the field is seldom updated, we append the revision number
  version '0.0.1'
  sha256 'feec05d921ceda2334aea8eb4e5eadcc3194508df1dcb0398cd8b994effb31ee'

  # head 'https://drone.io/github.com/monochromegane/the_platinum_searcher/files/artifacts/bin/darwin_amd64/pt', :using => :curl

  # def caveats; <<-EOS.undent
  #   EOS
  # end
end

