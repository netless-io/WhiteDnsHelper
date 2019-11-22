//
//  WhiteViewController.m
//  WhiteSDK
//
//  Created by leavesster on 08/12/2018.
//  Copyright (c) 2018 leavesster. All rights reserved.
//

#import "WhiteRoomViewController.h"

@interface WhiteRoomViewController ()<WhiteRoomCallbackDelegate, WhiteCommonCallbackDelegate, UIPopoverPresentationControllerDelegate>

@property (nonatomic, copy) NSString *roomToken;
@property (nonatomic, assign, getter=isReconnecting) BOOL reconnecting;

@end

#import <Masonry/Masonry.h>
#import "RoomCommandListController.h"

@implementation WhiteRoomViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor orangeColor];
    
    //锁死房间，不做多余逻辑
    self.roomUuid = @"8dbe7cd4b51b4ba3a061347abf6b2bcb";
    [self joinRoomWithToken:@"WHITEcGFydG5lcl9pZD1OZ3pwQWNBdlhiemJERW9NY0E0Z0V3RTUwbVZxM0NIbDJYV0Ymc2lnPTU4YjI4MmMzN2IxYjZkODQzYjNkYTE4YTg1OTM4NDRjYWQzYzQzNmY6YWRtaW5JZD0yMTYmcm9vbUlkPThkYmU3Y2Q0YjUxYjRiYTNhMDYxMzQ3YWJmNmIyYmNiJnRlYW1JZD0zNDEmcm9sZT1yb29tJmV4cGlyZV90aW1lPTE2MDU4OTgwMjEmYWs9Tmd6cEFjQXZYYnpiREVvTWNBNGdFd0U1MG1WcTNDSGwyWFdGJmNyZWF0ZV90aW1lPTE1NzQzNDEwNjkmbm9uY2U9MTU3NDM0MTA2OTQ3NDAw"];
}

#pragma mark - CallbackDelegate
- (id<WhiteRoomCallbackDelegate>)roomCallbackDelegate
{
    if (!_roomCallbackDelegate) {
        _roomCallbackDelegate = self;
    }
    return _roomCallbackDelegate;
}

#pragma mark - BarItem
- (void)setupShareBarItem
{
    UIBarButtonItem *item1 = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"设置 API", nil) style:UIBarButtonItemStylePlain target:self action:@selector(settingAPI:)];
    UIBarButtonItem *item2 = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"分享", nil) style:UIBarButtonItemStylePlain target:self action:@selector(shareRoom:)];
    UIBarButtonItem *item3 = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"pre", nil) style:UIBarButtonItemStylePlain target:self action:@selector(pptPreviousStep)];
    UIBarButtonItem *item4 = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"next", nil) style:UIBarButtonItemStylePlain target:self action:@selector(pptNextStep)];
    
    self.navigationItem.rightBarButtonItems = @[item1, item2, item3, item4];
}

- (void)pptPreviousStep
{
    [self.room pptPreviousStep];
}

- (void)pptNextStep
{
    [self.room pptNextStep];
}

- (void)settingAPI:(id)sender
{
    RoomCommandListController *controller = [[RoomCommandListController alloc] initWithRoom:self.room];
    controller.roomToken = self.roomToken;
    [self showPopoverViewController:controller sourceView:sender];
}

- (void)shareRoom:(id)sender
{
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[self.roomUuid ? :@""] applicationActivities:nil];
    activityVC.popoverPresentationController.sourceView = [self.navigationItem.rightBarButtonItem valueForKey:@"view"];
    [self presentViewController:activityVC animated:YES completion:nil];
    NSLog(@"%@", [NSString stringWithFormat:NSLocalizedString(@"房间 UUID: %@", nil), self.roomUuid]);
}

- (void)joinRoomWithToken:(NSString *)roomToken
{
    self.title = NSLocalizedString(@"正在连接房间", nil);
    
    NSDictionary *payload = @{@"avatar": @"https://white-pan.oss-cn-shanghai.aliyuncs.com/40/image/mask.jpg"};
    WhiteRoomConfig *roomConfig = [[WhiteRoomConfig alloc] initWithUuid:self.roomUuid roomToken:roomToken userPayload:payload];
    [self.sdk joinRoomWithConfig:roomConfig callbacks:self.roomCallbackDelegate completionHandler:^(BOOL success, WhiteRoom * _Nonnull room, NSError * _Nonnull error) {
        if (success) {
            self.title = NSLocalizedString(@"我的白板", nil);

            self.roomToken = roomToken;
            self.room = room;
            [self.room addMagixEventListener:WhiteCommandCustomEvent];
            [self setupShareBarItem];
            
            if (self.roomBlock) {
                self.roomBlock(self.room, nil);
            }
        } else if (self.roomBlock) {
            self.roomBlock(nil, error);
        } else {
            self.title = NSLocalizedString(@"加入失败", nil);
            UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"加入房间失败", nil) message:[NSString stringWithFormat:@"错误信息:%@", [error localizedDescription]] preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *action = [UIAlertAction actionWithTitle:NSLocalizedString(@"确定", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                [self.navigationController popViewControllerAnimated:YES];
            }];
            [alertVC addAction:action];
            [self presentViewController:alertVC animated:YES completion:nil];
        }
    }];
}

#pragma mark - Keyboard

- (void)setRectangle {
    [self.room getSceneStateWithResult:^(WhiteSceneState * _Nonnull state) {
        if (state.scenes) {
            WhitePptPage *ppt = state.scenes[state.index].ppt;
            WhiteRectangleConfig *rectangle = [[WhiteRectangleConfig alloc] initWithInitialPosition:ppt.width height:ppt.height];
            [self.room moveCameraToContainer:rectangle];
        }
    }];
}

/**
 处理文字教具键盘隐藏时，内容偏移。
 可以
 @param n 键盘通知
 */
- (void)keyboardDidDismiss:(NSNotification *)n
{
    [self.boardView.scrollView setContentOffset:CGPointZero animated:YES];
}

#pragma mark - WhiteRoomCallbackDelegate
- (void)firePhaseChanged:(WhiteRoomPhase)phase
{
    NSLog(@"%s, %ld", __FUNCTION__, (long)phase);
    if (phase == WhiteRoomPhaseDisconnected && self.sdk && !self.isReconnecting) {
        self.reconnecting = YES;
        [self.sdk joinRoomWithUuid:self.roomUuid roomToken:self.roomToken completionHandler:^(BOOL success, WhiteRoom *room, NSError *error) {
            self.reconnecting = NO;
            NSLog(@"reconnected");
            if (error) {
                NSLog(@"error:%@", [error localizedDescription]);
            } else {
                self.room = room;
            }
        }];
    }
}

- (void)fireRoomStateChanged:(WhiteRoomState *)magixPhase;
{
    NSLog(@"%s, %@", __func__, [magixPhase jsonString]);
}

- (void)fireBeingAbleToCommitChange:(BOOL)isAbleToCommit
{
    NSLog(@"%s, %d", __func__, isAbleToCommit);
}

- (void)fireDisconnectWithError:(NSString *)error
{
    NSLog(@"%s, %@", __func__, error);
}

- (void)fireKickedWithReason:(NSString *)reason
{
    NSLog(@"%s, %@", __func__, reason);
}

- (void)fireCatchErrorWhenAppendFrame:(NSUInteger)userId error:(NSString *)error
{
    NSLog(@"%s, %lu %@", __func__, (unsigned long)userId, error);
}

- (void)fireMagixEvent:(WhiteEvent *)event
{
    NSLog(@"fireMagixEvent: %@", [event jsonString]);
}

- (void)fireHighFrequencyEvent:(NSArray<WhiteEvent *>*)events
{
    NSLog(@"%s", __func__);
}

@end
