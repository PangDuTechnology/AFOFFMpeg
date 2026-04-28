
Pod::Spec.new do |s|

  # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.name         = "AFOFFMpeg"
  s.version      = "0.1.11"
  s.summary      = "decoding."

  # This description is used to generate tags and improve search results.
  s.description  = 'Use soft decode to decode video.'
  s.homepage     = "https://github.com/PangDuTechnology/AFOFFMpeg.git"
  # ―――  Spec License  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.license      = "MIT"
  # ――― Author Metadata  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.author             = { "PangDu" => "xian312117@gmail.com" }
  # ――― Platform Specifics ――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.ios.deployment_target = "13.0"
  # ――― Source Location ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.source       = { :git => "https://github.com/PangDuTechnology/AFOFFMpeg.git", :tag => s.version.to_s }
  s.default_subspecs = 'play', 'media', 'screenshots', 'audio', 'error', 'manager'
  # ――― Source Code ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.source_files  = "AFOFFMpeg/*.{h,m}"
  s.public_header_files = "AFOFFMpeg/*.h"

  s.subspec 'play' do |play|
      play.dependency 'AFOFFMpeg/manager'
      play.source_files = 'AFOFFMpeg/play/*.{h,m}' 
      play.public_header_files = 'AFOFFMpeg/play/*.h'
  end

  s.subspec 'media' do |media|
      media.dependency 'AFOFFMpeg/error'
      media.source_files = 'AFOFFMpeg/media/*.{h,m}' 
      media.public_header_files = 'AFOFFMpeg/media/*.h'
  end

  s.subspec 'screenshots' do |screenshots|
      screenshots.dependency 'AFOFFMpeg/media'
      screenshots.dependency 'AFOFFMpeg/error'
      screenshots.source_files = 'AFOFFMpeg/screenshots/*.{h,m}' 
      screenshots.public_header_files = 'AFOFFMpeg/screenshots/*.h'
  end

  s.subspec 'audio' do |audio|
      audio.source_files = 'AFOFFMpeg/audio/*.{h,m}' 
      audio.public_header_files = 'AFOFFMpeg/audio/*.h'
  end

  s.subspec 'error' do |error|
      error.source_files = 'AFOFFMpeg/error/*.{h,m}' 
      error.public_header_files = 'AFOFFMpeg/error/*.h'
  end

  s.subspec 'manager' do |manager|
      manager.dependency 'AFOFFMpeg/media'
      manager.dependency 'AFOFFMpeg/audio'
      manager.source_files = 'AFOFFMpeg/manager/*.{h,m}' 
      manager.public_header_files = 'AFOFFMpeg/manager/*.h'
  end
  # ――― Resources ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  # ――― Project Linking ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  # ――― Project Settings ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  # CoreAudioTypes 勿写进 s.frameworks：部分 Xcode/iOS SDK 下 ld 报「framework 'CoreAudioTypes' not found」；类型与符号由 AudioToolbox、AVFoundation 等已覆盖。
  s.frameworks = 'UIKit', 'Foundation', 'VideoToolbox', 'CoreMedia', 'CoreVideo', 'CoreGraphics', 'CoreImage', 'OpenGLES', 'Metal', 'MetalKit', 'AVFoundation', 'AudioToolbox', 'Accelerate', 'QuartzCore'
  # FFmpeg/AFOFFMpegLib 静态链路常见依赖；lint 宿主 App 不会自动补全时需显式声明
  s.libraries = 'z', 'bz2', 'iconv', 'c++'
  # 勿对宿主 App 使用 -all_load。Categories 仅用 -ObjC（勿用 -lObjC：会按 libObjC 解析，易链接失败）。
  # 压缩/运行时库由 s.libraries 展开为 -lz -lbz2 -liconv -lc++，勿在 OTHER_LDFLAGS 里重复写两套。
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC',
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
  }
  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC',
    'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks',
  }
  s.static_framework = true
  s.requires_arc = true
  s.dependency "AFOFoundation"
  s.dependency "AFORouter"
  s.dependency "AFOUIKIT"
  s.dependency "AFOGitHub"
  s.dependency "AFOViews"
  s.dependency "AFODelegateExtension"
  s.dependency "AFOFFMpegLib"
  s.dependency "AFOlibyuv"
  s.dependency "libxvidcore", "~> 0.0.4"
  s.dependency "AFOx264", "~> 0.1.1"
  s.dependency "AFOSchedulerCore"
end
