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
    // 简化着色器代码，实际会从文件加载
    NSString *shaderSource = @"\n"
    "using namespace metal;\n"
    "\n"
    "struct AFOVertexIn {\n"
    "    float2 position    [[attribute(0)]];\n"
    "    float2 textureCoordinate [[attribute(1)]];\n"
    "};\n"
    "\n"
    "struct AFOVertexOut {\n"
    "    float4 position    [[position]];\n"
    "    float2 textureCoordinate;\n"
    "};\n"
    "\n"
    "vertex AFOVertexOut vertexShader(AFOVertexIn in [[stage_in]]) {\n"
    "    AFOVertexOut out;\n"
    "    out.position = float4(in.position, 0.0, 1.0);\n"
    "    out.textureCoordinate = in.textureCoordinate;\n    return out;\n"
    "}\n"
    "\n"
    "fragment float4 fragmentShader(AFOVertexOut in [[stage_in]],\n"
    "                                texture2d<float> yTexture [[texture(0)]],\n"
    "                                texture2d<float> uvTexture [[texture(1)]]) {\n"
    "    constexpr sampler s(address::clamp_to_edge, filter::linear);\n"
    "    float y = yTexture.sample(s, in.textureCoordinate).r;\n"
    "    float2 uv = uvTexture.sample(s, in.textureCoordinate).rg;\n"
    "    float r = y + 1.402 * (uv.y - 0.5);\n"
    "    float g = y - 0.344 * (uv.x - 0.5) - 0.714 * (uv.y - 0.5);\n    float b = y + 1.772 * (uv.x - 0.5);\n    return float4(r, g, b, 1.0);\n"
    "}\n";

    id<MTLLibrary> defaultLibrary = [_device newLibraryWithSource:shaderSource options:nil error:nil];
    id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
    id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];

    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.vertexFunction = vertexFunction;
    pipelineStateDescriptor.fragmentFunction = fragmentFunction;
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = self.colorPixelFormat;

    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:nil];
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
    if (!_yTexture || !_uvTexture) {
        return;
    }

    _renderPassDescriptor = view.currentRenderPassDescriptor;
    if (_renderPassDescriptor == nil) {
        return;
    }

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_renderPassDescriptor];
    [renderEncoder setRenderPipelineState:_pipelineState];
    [renderEncoder setVertexBuffer:_vertices offset:0 atIndex:0];
    [renderEncoder setFragmentTexture:_yTexture atIndex:0];
    [renderEncoder setFragmentTexture:_uvTexture atIndex:1];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
    [renderEncoder endEncoding];
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];

    // 释放纹理
    _yTexture = nil;
    _uvTexture = nil;
}

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    if (!pixelBuffer) {
        return;
    }

    CVMetalTextureRef yTextureRef = NULL;
    CVMetalTextureRef uvTextureRef = NULL;

    // Y-plane
    CVReturn status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                _textureCache,
                                                                pixelBuffer,
                                                                nil,
                                                                MTLPixelFormatR8Unorm,
                                                                CVPixelBufferGetWidthOfPlane(pixelBuffer, 0),
                                                                CVPixelBufferGetHeightOfPlane(pixelBuffer, 0),
                                                                0,
                                                                &yTextureRef);
    if (status == kCVReturnSuccess) {
        _yTexture = CVMetalTextureGetTexture(yTextureRef);
        CFRelease(yTextureRef);
    }

    // UV-plane
    status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       _textureCache,
                                                       pixelBuffer,
                                                       nil,
                                                       MTLPixelFormatRG8Unorm, // 对于 NV12 格式
                                                       CVPixelBufferGetWidthOfPlane(pixelBuffer, 1),
                                                       CVPixelBufferGetHeightOfPlane(pixelBuffer, 1),
                                                       1,
                                                       &uvTextureRef);
    if (status == kCVReturnSuccess) {
        _uvTexture = CVMetalTextureGetTexture(uvTextureRef);
        CFRelease(uvTextureRef);
    }

    // 调用 MTKView 的 draw 方法
    [self draw];
}

- (void)dealloc {
    if (_textureCache) {
        CFRelease(_textureCache);
        _textureCache = NULL;
    }
}

@end
