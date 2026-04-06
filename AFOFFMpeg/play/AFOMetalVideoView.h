//
//  AFOMetalVideoView.h
//  AFOFFMpeg
//
//  Created by zhaoyun on 2026/4/6.
//

#import <UIKit/UIKit.h>
#import <MetalKit/MetalKit.h>
#import <CoreVideo/CVMetalTextureCache.h>

NS_ASSUME_NONNULL_BEGIN

@interface AFOMetalVideoView : MTKView

// 初始化方法
- (instancetype)initWithFrame:(CGRect)frame;

// 渲染 CVPixelBufferRef
- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end

NS_ASSUME_NONNULL_END
