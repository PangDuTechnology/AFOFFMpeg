//
//  AFOMetalVideoView.m
//  AFOFFMpeg
//
//  Created by zhaoyun on 2026/4/6.
//

#import "AFOMetalVideoView.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <simd/simd.h>

/// 解码定时器在全局队列上回调，Metal/UIKit 必须在主线程更新，否则易出现闪屏、花屏或偏绿闪烁。
static void AFO_MetalVideoViewRunOnMain(void (^work)(void)) {
    if ([NSThread isMainThread]) {
        work();
    } else {
        dispatch_async(dispatch_get_main_queue(), work);
    }
}

// 顶点数据结构
typedef struct {
    vector_float2 position;
    vector_float2 textureCoordinate;
} AFOVertex;

@interface AFOMetalVideoView () <MTKViewDelegate>

@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLBuffer> vertices;
@property (nonatomic, strong) id<MTLTexture> yTexture;
@property (nonatomic, strong) id<MTLTexture> uvTexture;
@property (nonatomic, assign) CVMetalTextureCacheRef textureCache;
@property (nonatomic, assign) vector_float2 viewportSize;
/// 当前帧像素尺寸，用于计算 scaleAspectFit，避免拉伸变形
@property (nonatomic, assign) CGFloat videoContentWidth;
@property (nonatomic, assign) CGFloat videoContentHeight;

@end

@implementation AFOMetalVideoView

+ (Class)layerClass {
    return [CAMetalLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupMetalView];
    }
    return self;
}

- (void)setupMetalView {
    self.device = MTLCreateSystemDefaultDevice();
    if (!self.device) {
        NSLog(@"AFOMetalVideoView: Metal is not supported on this device.");
        return;
    }

    MTKView *mtkView = (MTKView *)self;
    mtkView.device = self.device;
    mtkView.delegate = self;
    mtkView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    mtkView.clearColor = MTLClearColorMake(0, 0, 0, 1);
    mtkView.autoResizeDrawable = YES;
    mtkView.contentMode = UIViewContentModeScaleAspectFit;
    mtkView.preferredFramesPerSecond = 30;
    mtkView.paused = YES;
    mtkView.enableSetNeedsDisplay = YES;

    self.commandQueue = [self.device newCommandQueue];
    _videoContentWidth = 0;
    _videoContentHeight = 0;

    [self setupTextureCache];
    [self setupPipeline];
    [self afo_rebuildVertexBufferForAspectFit];
    
    NSLog(@"AFOMetalVideoView: Metal view setup completed successfully.");
}

- (void)setupTextureCache {
    CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, self.device, nil, &_textureCache);
}

- (void)setupPipeline {
    NSError *error = nil;
    NSString *shaderPath = [[NSBundle mainBundle] pathForResource:@"default" ofType:@"metallib"];
    NSLog(@"AFOMetalVideoView: Attempting to load Metal library from path: %@", shaderPath);

    id<MTLLibrary> defaultLibrary = nil;
    if (shaderPath.length > 0) {
        defaultLibrary = [self.device newLibraryWithFile:shaderPath error:&error];
    }
    if (error || !defaultLibrary) {
        // 兜底：工程未打包 metallib 时，运行时编译最小 NV12 Shader，避免黑屏。
        error = nil;
        static NSString * const kAFOEmbeddedMetalSource =
        @"#include <metal_stdlib>\n"
        @"using namespace metal;\n"
        @"\n"
        @"struct VertexIn {\n"
        @"  float2 position [[attribute(0)]];\n"
        @"  float2 texCoord [[attribute(1)]];\n"
        @"};\n"
        @"\n"
        @"struct VertexOut {\n"
        @"  float4 position [[position]];\n"
        @"  float2 texCoord;\n"
        @"};\n"
        @"\n"
        @"vertex VertexOut vertexShader(VertexIn in [[stage_in]]) {\n"
        @"  VertexOut out;\n"
        @"  out.position = float4(in.position, 0.0, 1.0);\n"
        @"  out.texCoord = in.texCoord;\n"
        @"  return out;\n"
        @"}\n"
        @"\n"
        @"fragment float4 fragmentShader(VertexOut in [[stage_in]],\n"
        @"                             texture2d<float, access::sample> yTex [[texture(0)]],\n"
        @"                             texture2d<float, access::sample> uvTex [[texture(1)]]) {\n"
        @"  constexpr sampler s(address::clamp_to_edge, filter::linear);\n"
        @"  float y = yTex.sample(s, in.texCoord).r;\n"
        @"  float2 uv = uvTex.sample(s, in.texCoord).rg - float2(0.5, 0.5);\n"
        @"  float r = y + 1.402 * uv.y;\n"
        @"  float g = y - 0.344136 * uv.x - 0.714136 * uv.y;\n"
        @"  float b = y + 1.772 * uv.x;\n"
        @"  return float4(r, g, b, 1.0);\n"
        @"}\n";

        MTLCompileOptions *options = [[MTLCompileOptions alloc] init];
        if (@available(iOS 16.0, *)) {
            options.languageVersion = MTLLanguageVersion3_0;
        }
        defaultLibrary = [self.device newLibraryWithSource:kAFOEmbeddedMetalSource options:options error:&error];
        if (error || !defaultLibrary) {
            NSLog(@"AFOMetalVideoView: Failed to create library (file+embedded). %@", error.localizedDescription);
            return;
        }
        NSLog(@"AFOMetalVideoView: Using embedded Metal shader library.");
    }

    id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
    id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];

    if (!vertexFunction || !fragmentFunction) {
        NSLog(@"AFOMetalVideoView: Failed to find shader functions. vertex: %@, fragment: %@", 
              vertexFunction ? @"found" : @"missing", 
              fragmentFunction ? @"found" : @"missing");
        return;
    }

    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.vertexFunction = vertexFunction;
    pipelineDescriptor.fragmentFunction = fragmentFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

    MTLVertexDescriptor *vertexDescriptor = [[MTLVertexDescriptor alloc] init];
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat2;
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[0].bufferIndex = 0;
    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat2;
    vertexDescriptor.attributes[1].offset = sizeof(float) * 2;
    vertexDescriptor.attributes[1].bufferIndex = 0;
    vertexDescriptor.layouts[0].stride = sizeof(float) * 4;
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;

    pipelineDescriptor.vertexDescriptor = vertexDescriptor;

    _pipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (error) {
        NSLog(@"AFOMetalVideoView: Failed to create pipeline state: %@", error.localizedDescription);
    } else {
        NSLog(@"AFOMetalVideoView: Successfully created render pipeline state.");
    }
}

/// 按视频与 drawable 宽高比做 scaleAspectFit，黑边填充，不变形。
- (void)afo_rebuildVertexBufferForAspectFit {
    CGFloat vw = (CGFloat)self.drawableSize.width;
    CGFloat vh = (CGFloat)self.drawableSize.height;
    if (vw < 1.0 || vh < 1.0) {
        CGFloat scale = self.window.screen.scale ?: UIScreen.mainScreen.scale;
        vw = CGRectGetWidth(self.bounds) * scale;
        vh = CGRectGetHeight(self.bounds) * scale;
    }
    CGFloat cw = self.videoContentWidth;
    CGFloat ch = self.videoContentHeight;
    if (cw < 1.0 || ch < 1.0) {
        cw = MAX(vw, 1.0);
        ch = MAX(vh, 1.0);
    }

    CGFloat arView = vw / vh;
    CGFloat arVideo = cw / ch;
    CGFloat sx = 1.0f;
    CGFloat sy = 1.0f;
    if (arView > arVideo) {
        sx = arVideo / arView;
    } else {
        sy = arView / arVideo;
    }

    AFOVertex quadVertices[] = {
        {{-sx, -sy}, {0.0f, 1.0f}},
        {{ sx, -sy}, {1.0f, 1.0f}},
        {{-sx,  sy}, {0.0f, 0.0f}},
        {{ sx, -sy}, {1.0f, 1.0f}},
        {{ sx,  sy}, {1.0f, 0.0f}},
        {{-sx,  sy}, {0.0f, 0.0f}},
    };

    const NSUInteger len = sizeof(quadVertices);
    if (!_vertices || _vertices.length < len) {
        _vertices = [self.device newBufferWithLength:len options:MTLResourceStorageModeShared];
    }
    memcpy(_vertices.contents, quadVertices, len);
}

#pragma mark - MTKViewDelegate

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;
    NSLog(@"AFOMetalVideoView: Drawable size changed to %.0fx%.0f", size.width, size.height);
    [self afo_rebuildVertexBufferForAspectFit];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self afo_rebuildVertexBufferForAspectFit];
}

- (void)drawInMTKView:(MTKView *)view {
    if (self.paused || !_yTexture || !_uvTexture || !_vertices) {
        return;
    }

    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    if (!renderPassDescriptor) {
        NSLog(@"AFOMetalVideoView: currentRenderPassDescriptor is nil");
        return;
    }

    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];

    [renderEncoder setRenderPipelineState:self.pipelineState];
    [renderEncoder setVertexBuffer:self.vertices offset:0 atIndex:0];
    [renderEncoder setFragmentTexture:self.yTexture atIndex:0];
    [renderEncoder setFragmentTexture:self.uvTexture atIndex:1];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];

    [renderEncoder endEncoding];
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];

    // 绘制一次后暂停，避免重复绘制相同帧
    self.paused = YES;
}

#pragma mark - Public Methods

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    if (!pixelBuffer) {
        AFO_MetalVideoViewRunOnMain(^{
            [self afo_applyPixelBufferAndDraw:nil];
        });
        return;
    }
    if (![NSThread isMainThread]) {
        CVPixelBufferRetain(pixelBuffer);
        AFO_MetalVideoViewRunOnMain(^{
            [self afo_applyPixelBufferAndDraw:pixelBuffer];
            CVPixelBufferRelease(pixelBuffer);
        });
        return;
    }
    [self afo_applyPixelBufferAndDraw:pixelBuffer];
}

/// 必须在主线程调用；若 Y/UV Metal 纹理未同时创建成功，保留上一帧纹理，避免出现半帧/脏缓存导致的偏色闪烁。
- (void)afo_applyPixelBufferAndDraw:(CVPixelBufferRef)pixelBuffer {
    NSAssert([NSThread isMainThread], @"Metal/CVPixelBuffer upload must run on main thread");

    if (!pixelBuffer) {
        self.paused = YES;
        self.yTexture = nil;
        self.uvTexture = nil;
        if (_currentPixelBuffer) {
            CVPixelBufferRelease(_currentPixelBuffer);
            _currentPixelBuffer = nil;
        }
        return;
    }

    size_t planeCount = CVPixelBufferGetPlaneCount(pixelBuffer);
    if (planeCount < 2) {
        NSLog(@"AFOMetalVideoView: skip frame — expected biplanar NV12, planeCount=%zu", planeCount);
        return;
    }

    NSLog(@"AFOMetalVideoView: ✅ Received CVPixelBufferRef. Address: %p, Format: %u, Size: %dx%d",
          pixelBuffer,
          (unsigned int)CVPixelBufferGetPixelFormatType(pixelBuffer),
          (int)CVPixelBufferGetWidth(pixelBuffer),
          (int)CVPixelBufferGetHeight(pixelBuffer));

    CVMetalTextureCacheFlush(self.textureCache, 0);

    CVMetalTextureRef yTextureRef = NULL;
    CVMetalTextureRef uvTextureRef = NULL;

    CVReturn yStatus = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                 self.textureCache,
                                                                 pixelBuffer,
                                                                 nil,
                                                                 MTLPixelFormatR8Unorm,
                                                                 CVPixelBufferGetWidthOfPlane(pixelBuffer, 0),
                                                                 CVPixelBufferGetHeightOfPlane(pixelBuffer, 0),
                                                                 0,
                                                                 &yTextureRef);
    CVReturn uvStatus = kCVReturnError;
    if (yStatus == kCVReturnSuccess && yTextureRef) {
        uvStatus = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                               self.textureCache,
                                                               pixelBuffer,
                                                               nil,
                                                               MTLPixelFormatRG8Unorm,
                                                               CVPixelBufferGetWidthOfPlane(pixelBuffer, 1),
                                                               CVPixelBufferGetHeightOfPlane(pixelBuffer, 1),
                                                               1,
                                                               &uvTextureRef);
    }

    id<MTLTexture> newY = (yStatus == kCVReturnSuccess && yTextureRef) ? CVMetalTextureGetTexture(yTextureRef) : nil;
    id<MTLTexture> newUV = (uvStatus == kCVReturnSuccess && uvTextureRef) ? CVMetalTextureGetTexture(uvTextureRef) : nil;

    if (yTextureRef) {
        CFRelease(yTextureRef);
    }
    if (uvTextureRef) {
        CFRelease(uvTextureRef);
    }

    if (!newY || !newUV) {
        NSLog(@"AFOMetalVideoView: ❌ Metal texture failed (yStatus=%d uvStatus=%d) — keeping previous frame.", (int)yStatus, (int)uvStatus);
        return;
    }

    if (_currentPixelBuffer) {
        CVPixelBufferRelease(_currentPixelBuffer);
    }
    _currentPixelBuffer = CVPixelBufferRetain(pixelBuffer);

    self.videoContentWidth = (CGFloat)CVPixelBufferGetWidth(pixelBuffer);
    self.videoContentHeight = (CGFloat)CVPixelBufferGetHeight(pixelBuffer);
    [self afo_rebuildVertexBufferForAspectFit];

    self.yTexture = newY;
    self.uvTexture = newUV;

    NSLog(@"AFOMetalVideoView: ✅ Y/UV textures updated, drawing.");
    self.paused = NO;
    [self setNeedsDisplay];
}

- (void)dealloc {
    if (self.textureCache) {
        CFRelease(self.textureCache);
        self.textureCache = NULL;
    }
    if (_currentPixelBuffer) {
        CVPixelBufferRelease(_currentPixelBuffer);
        _currentPixelBuffer = NULL;
    }
    NSLog(@"AFOMetalVideoView: dealloc called.");
}

@end
