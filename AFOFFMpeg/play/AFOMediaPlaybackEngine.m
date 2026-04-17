//
//  AFOMediaPlaybackEngine.m
//  AFOFFMpeg
//
//  Created by Cursor.
//

#import "AFOMediaPlaybackEngine.h"
#import "AFOTotalDispatchManager.h"

@interface AFOMediaPlaybackEngine ()
@property (nonatomic, strong) AFOTotalDispatchManager *dispatchManager;
@end

@implementation AFOMediaPlaybackEngine

- (instancetype)init {
    self = [super init];
    if (self) {
        _dispatchManager = [[AFOTotalDispatchManager alloc] init];
    }
    return self;
}

- (void)playPath:(NSString *)path callback:(AFOMediaPlaybackFrameCallback)callback {
    if (!callback) {
        return;
    }
    [self.dispatchManager displayVedioForPath:path block:^(NSError * _Nullable error,
                                                           CVPixelBufferRef  _Nullable pixelBuffer,
                                                           NSString * _Nullable totalTime,
                                                           NSString * _Nullable currentTime,
                                                           NSInteger totalSeconds,
                                                           NSUInteger cuttentSeconds,
                                                           BOOL isVideoEnd) {
        callback(error, pixelBuffer, totalTime, currentTime, totalSeconds, cuttentSeconds, isVideoEnd);
    }];
}

- (void)stop {
    [self.dispatchManager stop];
}

- (void)setSuspended:(BOOL)suspended {
    [self.dispatchManager setSuspended:suspended];
}

@end

