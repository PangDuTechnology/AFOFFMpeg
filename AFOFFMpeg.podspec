
Pod::Spec.new do |s|

  # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.name         = "AFOFFMpeg"
  s.version      = "0.0.24"
  s.summary      = "decoding."

  # This description is used to generate tags and improve search results.
  s.description  = 'Use soft decode to decode video.'
  s.homepage     = "https://github.com/PangDuTechnology/AFOFFMpeg.git"
  # ―――  Spec License  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.license      = "MIT"
  # ――― Author Metadata  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.author             = { "PangDu" => "xian312117@gmail.com" }
  # ――― Platform Specifics ――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.platform     = :ios, "8.0"
  s.ios.deployment_target = '8.0'

  # ――― Source Location ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.source       = { :git => "https://github.com/PangDuTechnology/AFOFFMpeg.git", :tag => s.version.to_s }
  # ――― Source Code ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.source_files  = "AFOFFMpeg/**/*.{h,m}"
  s.public_header_files = "AFOFFMpeg/**/*.h"

  # ――― Resources ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  # ――― Project Linking ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  # ――― Project Settings ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.pod_target_xcconfig  =  {'OTHER_LDFLAGS'  =>  '-lObjC' }
  s.requires_arc = true
  s.dependency "AFOFoundation"
  s.dependency "AFORouter"
  s.dependency "AFOUIKIT"
  s.dependency "AFOGitHub"
  s.dependency "AFOViews"
  s.dependency "AFOFFMpegLib"
  s.dependency "AFOlibyuv"
end
