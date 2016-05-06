//
//  THPlayViewController.m
//  Kamera
//
//  Created by songzhao on 16/5/4.
//  Copyright © 2016年 Bob McCune. All rights reserved.
//

#import "THPlayViewController.h"
#import <AVKit/AVKit.h>
@interface THPlayViewController ()
@property (nonatomic, strong) AVPlayerViewController *playerVC;
@end

@implementation THPlayViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    NSMutableArray *items = @[].mutableCopy;
    for (NSURL *url in self.URLs) {
        AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
        [items addObject:item];
    }
    AVQueuePlayer* queuePlayer = [AVQueuePlayer queuePlayerWithItems:items.copy];
    
    AVPlayerViewController *vc = [[AVPlayerViewController alloc] init];
    vc.player = queuePlayer;
    vc.view.frame = self.view.bounds;
    [self.view  addSubview:vc.view];
    self.playerVC = vc;
//    AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:queuePlayer];
////    avPlayer.actionAtItemEnd = AVPlayerItemStatusReadyToPlay;
//    layer.frame = self.view.layer.bounds;
//    
//    [self.view.layer addSublayer:layer];
//    
//    [queuePlayer play];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
