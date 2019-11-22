//
//  WhitePlayerViewController.m
//  WhiteSDKPrivate_Example
//
//  Created by yleaf on 2019/3/2.
//  Copyright © 2019 leavesster. All rights reserved.
//

#import "WhitePlayerViewController.h"
#import "WhiteSDK.h"
#import "PlayerCommandListController.h"

@interface WhitePlayerViewController ()<WhiteCommonCallbackDelegate, WhitePlayerEventDelegate, UIPopoverPresentationControllerDelegate>
@property (nonatomic, nullable, strong) WhitePlayer *player;
@property (nonatomic, nullable, strong) NSString *roomToken;
@end

#import <Masonry/Masonry.h>

@implementation WhitePlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    UIBarButtonItem *item1 = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"设置", nil) style:UIBarButtonItemStylePlain target:self action:@selector(settingAPI:)];
    UIBarButtonItem *item2 = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"初始化", nil) style:UIBarButtonItemStylePlain target:self action:@selector(initPlayer)];
    //TODO:直接填入
    self.roomUuid = @"8dbe7cd4b51b4ba3a061347abf6b2bcb";
    self.roomToken = @"WHITEcGFydG5lcl9pZD1OZ3pwQWNBdlhiemJERW9NY0E0Z0V3RTUwbVZxM0NIbDJYV0Ymc2lnPTU4YjI4MmMzN2IxYjZkODQzYjNkYTE4YTg1OTM4NDRjYWQzYzQzNmY6YWRtaW5JZD0yMTYmcm9vbUlkPThkYmU3Y2Q0YjUxYjRiYTNhMDYxMzQ3YWJmNmIyYmNiJnRlYW1JZD0zNDEmcm9sZT1yb29tJmV4cGlyZV90aW1lPTE2MDU4OTgwMjEmYWs9Tmd6cEFjQXZYYnpiREVvTWNBNGdFd0U1MG1WcTNDSGwyWFdGJmNyZWF0ZV90aW1lPTE1NzQzNDEwNjkmbm9uY2U9MTU3NDM0MTA2OTQ3NDAw";
    [self initPlayer];
    self.navigationItem.rightBarButtonItems = @[item1, item2];
}

- (void)initPlayer
{
    WhiteSdkConfiguration *config = [WhiteSdkConfiguration defaultConfig];
    config.debug = YES;
    
    self.sdk = [[WhiteSDK alloc] initWithWhiteBoardView:self.boardView config:config commonCallbackDelegate:self.commonDelegate];
    WhitePlayerConfig *playerConfig = [[WhitePlayerConfig alloc] initWithRoom:self.roomUuid roomToken:self.roomToken];
    playerConfig.duration = @10;
    // 10s 左右的视频 m3u8
    playerConfig.audioUrl = @"https://netless-media.oss-cn-hangzhou.aliyuncs.com/c447a98ece45696f09c7fc88f649c082_3002a61acef14e4aa1b0154f734a991d.m3u8";
    [self.sdk createReplayerWithConfig:playerConfig callbacks:self.eventDelegate completionHandler:^(BOOL success, WhitePlayer * _Nonnull player, NSError * _Nonnull error) {
        if (self.playBlock) {
            self.playBlock(player, error);
        } else if (error) {
            NSLog(@"创建回放房间失败 error:%@", [error localizedDescription]);
        } else {
            self.player = player;
            [self.player play];
            [self.player addHighFrequencyEventListener:@"a" fireInterval:1000];
            NSLog(@"创建回放房间成功，开始回放");
        }
    }];
}

#pragma mark -

- (void)settingAPI:(id)sender
{
    PlayerCommandListController *controller = [[PlayerCommandListController alloc] initWithPlayer:self.player];
    [self showPopoverViewController:controller sourceView:sender];
}

#pragma mark - CallbackDelegate

- (id<WhitePlayerEventDelegate>)eventDelegate
{
    if (!_eventDelegate) {
        _eventDelegate = self;
    }
    return _eventDelegate;
}

#pragma mark - WhitePlayerEventDelegate

- (void)phaseChanged:(WhitePlayerPhase)phase
{
    NSLog(@"player %s %ld", __FUNCTION__, (long)phase);
}

- (void)loadFirstFrame
{
    NSLog(@"player %s", __FUNCTION__);
}

- (void)sliceChanged:(NSString *)slice
{
    NSLog(@"player %s slice:%@", __FUNCTION__, slice);
}

- (void)playerStateChanged:(WhitePlayerState *)modifyState
{
    NSString *str = [modifyState jsonString];
    NSLog(@"player %s state:%@", __FUNCTION__, str);
}

- (void)stoppedWithError:(NSError *)error
{
    NSLog(@"player %s error:%@", __FUNCTION__, error);
}

- (void)scheduleTimeChanged:(NSTimeInterval)time
{
    NSLog(@"player %s time:%f", __FUNCTION__, (double)time);
}

- (void)fireMagixEvent:(WhiteEvent *)event;
{
    NSLog(@"%s", __func__);
}

- (void)fireHighFrequencyEvent:(NSArray<WhiteEvent *>*)events;
{
    NSLog(@"%s %@", __func__, events);
}

#pragma mark - WhiteCommonCallback

- (void)throwError:(NSError *)error
{
    NSLog(@"throwError: %@", error.userInfo);
}

- (NSString *)urlInterrupter:(NSString *)url
{
    return @"https://white-pan-cn.oss-cn-hangzhou.aliyuncs.com/124/image/image.png";
}

@end
