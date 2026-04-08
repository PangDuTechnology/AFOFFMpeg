//
//  AFOMetalVideoView.m
//  AFOFFMpeg
//
//  Created by zhaoyun on 2026/4/6.
//

// AFOMetalVideoView.m
#import "AFOMetalVideoView.h"
#import <Metal/Metal.h>
#import <simd/simd.h>

// 顶点数据结构
typedef struct {
    vector_float2 position;
    vector_float2 textureCoordinate;
} AFOVertex;

@interface AFOMetalVideoView () <MTKViewDelegate> {
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;
    id<MTLRenderPipelineState> _pipelineState;
    id<MTLTexture> _yTexture;
    id<MTLTexture> _uvTexture;
    CVMetalTextureCacheRef _textureCache;
    id<MTLBuffer> _vertices;
    MTLRenderPassDescriptor *_renderPassDescriptor;

    vector_float2 _viewportSize;
}
@end

@implementation AFOMetalVideoView

+ (Class)layerClass {
    return [CAMetalLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.delegate = self;
        self.paused = YES;
        self.enableSetNeedsDisplay = YES;
        self.preferredFramesPerSecond = 30;
        _device = MTLCreateSystemDefaultDevice();
        if (!_device) {
            NSLog(@"Metal is not supported on this device.");
            return nil;
        }
        self.device = _device;
        self.colorPixelFormat = MTLPixelFormatBGRA8Unorm; // 根据需要调整
        self.framebufferOnly = YES;

        _commandQueue = [_device newCommandQueue];

        [self setupMetal];
        [self setupPipeline];
        [self setupVertices];
    }
    return self;
}

- (void)setupMetal {
    CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, _device, nil, &_textureCache);
}

- (void)setupPipeline {
    NSError *error = nil;
    NSString *shaderPath = [[NSBundle mainBundle] pathForResource:@"default" ofType:@"metallib"];
    NSLog(@"AFOMetalVideoView: Attempting to load Metal library from path: %@", shaderPath); // 添加这行日志

    id<MTLLibrary> defaultLibrary = [_device newLibraryWithFile:shaderPath error:&error];
    if (error) {
        NSLog(@"AFOMetalVideoView: Failed to create library from path: %@, Error: %@");
        return;
    }

    id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
    if (!vertexFunction) {
        NSLog(@"AFOMetalVideoView: Failed to find vertexShader in library: %@.", shaderPath);
        return;
    }

    id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];
    if (!fragmentFunction) {
        NSLog(@"AFOMetalVideoView: Failed to find fragmentShader in library: %@.", shaderPath);
        return;
    }

    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.vertexFunction = vertexFunction;
    pipelineStateDescriptor.fragmentFunction = fragmentFunction;
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = self.colorPixelFormat;

    MTLVertexDescriptor *vertexDescriptor = [[MTLVertexDescriptor alloc] init];

    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat2;
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[0].bufferIndex = 0;

    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat2;
    vertexDescriptor.attributes[1].offset = sizeof(float) * 2;
    vertexDescriptor.attributes[1].bufferIndex = 0;

    vertexDescriptor.layouts[0].stride = sizeof(float) * 4;
    vertexDescriptor.layouts[0].stepRate = 1;
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;

    pipelineStateDescriptor.vertexDescriptor = vertexDescriptor;

    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
    NSLog(@"AFOMetalVideoView: Successfully created render pipeline state."); // 添加成功日志
    if (error) {
        NSLog(@"AFOMetalVideoView: Failed to create render pipeline state: %@", error);
        return;
    }
}

- (void)setupVertices {
    AFOVertex quadVertices[] = {
        // Position, Texture Coordinate
        {{-1.0, -1.0}, {0.0, 1.0}},
        {{ 1.0, -1.0}, {1.0, 1.0}},
        {{-1.0,  1.0}, {0.0, 0.0}},

        {{ 1.0, -1.0}, {1.0, 1.0}},
        {{ 1.0,  1.0}, {1.0, 0.0}},
        {{-1.0,  1.0}, {0.0, 0.0}},
    };

    _vertices = [_device newBufferWithBytes:quadVertices length:sizeof(quadVertices) options:MTLResourceStorageModeShared];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;
}

- (void)drawInMTKView:(nonnull MTKView *)view {
    if (self.isPaused || !_yTexture || !_uvTexture) {
        return;
    }

    // 使用 MTKView 提供的 currentRenderPassDescriptor
    MTLRenderPassDescriptor *currentRenderPassDescriptor = view.currentRenderPassDescriptor;
    if (!currentRenderPassDescriptor) {
        NSLog(@"AFOMetalVideoView: currentRenderPassDescriptor is nil. Skipping draw.");
        return;
    }

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:currentRenderPassDescriptor];
    [renderEncoder setRenderPipelineState:_pipelineState];
    [renderEncoder setVertexBuffer:_vertices offset:0 atIndex:0];
    [renderEncoder setFragmentTexture:_yTexture atIndex:0];
    [renderEncoder setFragmentTexture:_uvTexture atIndex:1];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
    [renderEncoder endEncoding];
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
}

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    if (!pixelBuffer) {
        NSLog(@"AFOMetalVideoView: displayPixelBuffer received nil pixelBuffer.");
        self.paused = YES;
        _yTexture = nil;
        _uvTexture = nil;
        if (self.currentPixelBuffer) { // 释放旧的 pixelBuffer
            CVPixelBufferRelease(self.currentPixelBuffer);
            self.currentPixelBuffer = nil;
        }
        return;
    }
    self.paused = NO;
    NSLog(@"AFOMetalVideoView: Received CVPixelBufferRef. Address: %p, Pixel Format: %u", pixelBuffer, CVPixelBufferGetPixelFormatType(pixelBuffer));

    // 如果有旧的 pixelBuffer，先释放它
    if (self.currentPixelBuffer) {
        CVPixelBufferRelease(self.currentPixelBuffer);
    }
    // 强引用新的 pixelBuffer
    self.currentPixelBuffer = CVPixelBufferRetain(pixelBuffer);

    CVMetalTextureRef yTextureRef = NULL;
    CVMetalTextureRef uvTextureRef = NULL;

    // Release existing textures to avoid drawing stale frames
    if (_yTexture) {
        _yTexture = nil;
    }
    if (_uvTexture) {
        _uvTexture = nil;
    }

    // Y-plane
    CVReturn status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                _textureCache,
                                                                self.currentPixelBuffer,
                                                                nil,
                                                                MTLPixelFormatR8Unorm,
                                                                CVPixelBufferGetWidthOfPlane(pixelBuffer, 0),
                                                                CVPixelBufferGetHeightOfPlane(pixelBuffer, 0),
                                                                0,
                                                                &yTextureRef);
    if (status == kCVReturnSuccess) {
        _yTexture = CVMetalTextureGetTexture(yTextureRef);
        if (yTextureRef) CFRelease(yTextureRef); // 确保在获取纹理后释放引用
        NSLog(@"AFOMetalVideoView: Successfully created Y texture. Address: %p", _yTexture); // 添加成功日志
    } else {
        NSLog(@"AFOMetalVideoView: Failed to create Y texture. Status: %d", status); // 添加错误日志
    }

    // UV-plane
    status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       _textureCache,
                                                       self.currentPixelBuffer,
                                                       nil,
                                                       MTLPixelFormatRG8Unorm, // 对于 NV12 格式
                                                       CVPixelBufferGetWidthOfPlane(pixelBuffer, 1),
                                                       CVPixelBufferGetHeightOfPlane(pixelBuffer, 1),
                                                       1,
                                                       &uvTextureRef);
    if (status == kCVReturnSuccess) {
        _uvTexture = CVMetalTextureGetTexture(uvTextureRef);
        if (uvTextureRef) CFRelease(uvTextureRef); // 确保在获取纹理后释放引用
        NSLog(@"AFOMetalVideoView: Successfully created UV texture. Address: %p", _uvTexture); // 添加成功日志
    } else {
        NSLog(@"AFOMetalVideoView: Failed to create UV texture. Status: %d", status); // 添加错误日志
    }

}

- (void)dealloc {
    if (_textureCache) {
        CFRelease(_textureCache);
        _textureCache = NULL;
    }
    if (_currentPixelBuffer) { // 在 dealloc 中释放持有的 pixelBuffer
        CVPixelBufferRelease(_currentPixelBuffer);
        _currentPixelBuffer = NULL;
    }
}

@end
