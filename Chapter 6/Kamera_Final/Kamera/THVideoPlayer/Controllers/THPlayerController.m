//
//  MIT License
//
//  Copyright (c) 2014 Bob McCune http://bobmccune.com/
//  Copyright (c) 2014 TapHarmonic, LLC http://tapharmonic.com/
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "THPlayerController.h"
#import "THThumbnail.h"
#import <AVFoundation/AVFoundation.h>
#import "THTransport.h"
#import "THPlayerView.h"
#import "AVAsset+THAdditions.h"
#import "UIAlertView+THAdditions.h"
#import "THNotifications.h"

// AVPlayerItem's status property
#define STATUS_KEYPATH @"status"

// Refresh interval for timed observations of AVPlayer
#define REFRESH_INTERVAL 0.5f

// Define this constant for the key-value observation context.
static const NSString *PlayerItemStatusContext;


@interface THPlayerController () <THTransportDelegate>

//@property (strong, nonatomic) AVAsset *asset;
@property (strong, nonatomic) AVPlayerItem *playerItem;
@property (strong, nonatomic) AVQueuePlayer *player;
@property (strong, nonatomic) THPlayerView *playerView;

@property (weak, nonatomic) id <THTransport> transport;

@property (strong, nonatomic) id timeObserver;
@property (strong, nonatomic) id itemEndObserver;
@property (assign, nonatomic) float lastPlaybackRate;

//@property (strong, nonatomic) AVAssetImageGenerator *imageGenerator;

@property (strong, nonatomic) NSMutableArray *assetURLs;
@property (strong, nonatomic) NSMutableArray *playerItems;
@property (nonatomic) NSInteger playerItemIndex;//当前分段标记
@property (nonatomic) NSTimeInterval queueDuration;//总时长
@property (nonatomic) NSTimeInterval normDuration;//分段标准时长
@end

@implementation THPlayerController

#pragma mark - Setup

- (id)initWithURLs:(NSArray *)assetURLs;
{
    self = [super init];
    if (self) {
        _assetURLs = [assetURLs mutableCopy];
        [self prepareToPlay];
    }
    return self;
}
- (void)prepareToPlay {
    
    self.playerItems = @[].mutableCopy;
    CMTime duration = kCMTimeZero;
    
    for (NSURL *aURL in self.assetURLs) {
        NSDictionary *opts = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO]
                                                         forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
        AVURLAsset *urlAsset = [AVURLAsset URLAssetWithURL:aURL options:opts];  // 初始化视频媒体文件
        CMTimeShow(urlAsset.duration);
        AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:urlAsset];
        [playerItem addObserver:self                                       // 3
                     forKeyPath:STATUS_KEYPATH
                        options:0
                        context:&PlayerItemStatusContext];
        [self.playerItems addObject:playerItem];
        CMTime tmp = playerItem.duration;
        duration = CMTimeAdd(tmp, duration);
    }
    self.queueDuration = CMTimeGetSeconds(duration);
#warning test
    self.player = [AVQueuePlayer queuePlayerWithItems:self.playerItems];
    self.playerItem = self.playerItems.firstObject;
    self.playerItemIndex = 0;
    self.normDuration = CMTimeGetSeconds(self.playerItem.duration);
    
    self.playerView = [[THPlayerView alloc] initWithPlayer:self.player];    // 5
    self.transport = self.playerView.transport;
    self.transport.delegate = self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    
    if (context == &PlayerItemStatusContext) {
        
        dispatch_async(dispatch_get_main_queue(), ^{                        // 1
            
            [self.playerItem removeObserver:self forKeyPath:STATUS_KEYPATH];
            if (self.playerItem.status == AVPlayerItemStatusReadyToPlay) {
                // Set up time observers.                                   // 2
                [self addPlayerItemTimeObserver];
                [self addItemEndObserverForPlayerItem];
                // Synchronize the time display                             // 3
                [self.transport setCurrentTime:CMTimeGetSeconds(kCMTimeZero)
                                      duration:self.queueDuration];
                // Set the video title.
                [self.transport setTitle:[self.playerItems[_playerItemIndex] asset].title];                 // 4
                [self.player play];                                         // 5
            } else {
                [UIAlertView showAlertWithTitle:@"Error"
                                        message:@"Failed to load video"];
            }
        });
    }
}


#pragma mark - Time Observers

- (void)addPlayerItemTimeObserver {
    
    // Create 0.5 second refresh interval - REFRESH_INTERVAL == 0.5
    CMTime interval =
    CMTimeMakeWithSeconds(REFRESH_INTERVAL, NSEC_PER_SEC);              // 1
    
    // Main dispatch queue
    dispatch_queue_t queue = dispatch_get_main_queue();                     // 2
    
    // Create callback block for time observer
    __weak THPlayerController *weakSelf = self;                             // 3
    
    // Add observer and store pointer for future use
    self.timeObserver =                                                     // 5
    [self.player addPeriodicTimeObserverForInterval:interval
                                              queue:queue
                                         usingBlock:^(CMTime time) {
                                             NSTimeInterval currentTime = CMTimeGetSeconds(time);
                                             NSTimeInterval duration = CMTimeGetSeconds(weakSelf.playerItem.duration);
                                             [weakSelf.transport setCurrentTime:currentTime duration:duration];  // 4
                                         }];
}

- (void)addItemEndObserverForPlayerItem {
    
    NSString *name = AVPlayerItemDidPlayToEndTimeNotification;
    
    NSOperationQueue *queue = [NSOperationQueue mainQueue];
    
    __weak THPlayerController *weakSelf = self;                             // 1
    void (^callback)(NSNotification *note) = ^(NSNotification *notification) {
        [weakSelf.player seekToTime:kCMTimeZero                             // 2
                  completionHandler:^(BOOL finished) {
                      [weakSelf.transport playbackComplete];                          // 3
                  }];
    };
    
    self.itemEndObserver =                                                  // 4
    [[NSNotificationCenter defaultCenter] addObserverForName:name
                                                      object:self.playerItem
                                                       queue:queue
                                                  usingBlock:callback];
}

#pragma mark - THTransportDelegate Methods

- (void)play {
    [self.player play];
}

- (void)pause {
    self.lastPlaybackRate = self.player.rate;
    [self.player pause];
}

- (void)stop {
    [self.player setRate:0.0f];
    [self.transport playbackComplete];
}

- (void)jumpedToTime:(NSTimeInterval)time {
    [self.player seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC)];
}

//- (void)scrubbingDidStart {                                                 // 1
//    self.lastPlaybackRate = self.player.rate;
//    [self.player pause];
//    [self.player removeTimeObserver:self.timeObserver];
//}
//
//- (void)scrubbedToTime:(NSTimeInterval)time {                               // 2
//    [self.playerItem cancelPendingSeeks];
//    [self.player seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
//}
//
//- (void)scrubbingDidEnd {                                                   // 3
//    [self addPlayerItemTimeObserver];
//    if (self.lastPlaybackRate > 0.0f) {
//        [self.player play];
//    }
//}
#pragma mark - 私有 methods
- (void)changePlayerItemWithTime:(NSTimeInterval)time;
{
    NSInteger index = self.queueDuration / time;
    NSTimeInterval subTime = @(modf(self.queueDuration, &time)).doubleValue;
    [self.playerItem cancelPendingSeeks];

    if (index != self.playerItemIndex) {
        //当前分段非目标分段，需切换PlayerItem
        self.playerItem = self.playerItems[index];
        [self.player replaceCurrentItemWithPlayerItem:self.playerItem];

    }
    CMTime newTime = CMTimeMakeWithSeconds(subTime, 1);
    [self.player seekToTime:newTime];
    [self.player play];
}
#pragma mark - Housekeeping

- (UIView *)view {
    return self.playerView;
}

- (void)dealloc {
    if (self.itemEndObserver) {                                             // 5
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc removeObserver:self.itemEndObserver
                      name:AVPlayerItemDidPlayToEndTimeNotification
                    object:self.player.currentItem];
        self.itemEndObserver = nil;
    }
}

@end
