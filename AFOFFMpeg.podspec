
Pod::Spec.new do |s|

  # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.name         = "AFOFFMpeg"
  s.version      = "0.1.1"
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
  s.source_files  = "AFOFFMpeg/*.{h,m}"
  s.public_header_files = "AFOFFMpeg/*.h"

  s.subspec 'play' do |play|
      play.dependency 'AFORouter'
      play.dependency 'AFOFoundation' 
      play.dependency 'AFOGitHub'
      play.source_files = 'AFOFFMpeg/play/*.{h,m}' 
      play.public_header_files = 'AFOFFMpeg/play/*.h'
  end

  s.subspec 'media' do |media|
      media.dependency 'AFORouter'
      media.dependency 'AFOFoundation' 
      media.dependency 'AFOGitHub'
      media.dependency 'AFOFFMpeg/error'
      media.dependency 'AFOFFMpegLib'
      media.source_files = 'AFOFFMpeg/media/*.{h,m}' 
      media.public_header_files = 'AFOFFMpeg/media/*.h'
  end

  s.subspec 'audio' do |audio|
      audio.dependency 'AFORouter'
      audio.dependency 'AFOFoundation' 
      audio.dependency 'AFOGitHub'
      audio.dependency 'AFOFFMpegLib'
      audio.source_files = 'AFOFFMpeg/audio/*.{h,m}' 
      audio.public_header_files = 'AFOFFMpeg/audio/*.h'
  end

  s.subspec 'error' do |error|
      error.source_files = 'AFOFFMpeg/error/*.{h,m}' 
      error.public_header_files = 'AFOFFMpeg/error/*.h'
  end

  s.subspec 'manager' do |manager|
      manager.dependency 'AFOFFMpeg/error'
      manager.source_files = 'AFOFFMpeg/manager/*.{h,m}' 
      manager.public_header_files = 'AFOFFMpeg/manager/*.h'
  end
  # ――― Resources ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  # ――― Project Linking ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  # ――― Project Settings ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.frameworks = 'VideoToolbox','CoreMedia','CoreGraphics','CoreImage','OpenGLES','AVFoundation','AudioToolbox'
  s.pod_target_xcconfig  =  {'OTHER_LDFLAGS'  =>  '-lObjC' }
  s.requires_arc = true
  s.dependency "AFOFoundation"
  s.dependency "AFORouter"
  s.dependency "AFOUIKIT"
  s.dependency "AFOGitHub"
  s.dependency "AFOViews"
  s.dependency "AFOFFMpegLib"
  s.dependency "AFOlibyuv"
  s.dependency "libxvidcore"
  s.dependency "AFOx264"
end
