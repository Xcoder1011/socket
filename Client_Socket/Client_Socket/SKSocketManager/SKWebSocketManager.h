//
//  SKWebSocketManager.h
//  Client_Socket
//
//  Created by KUN on 2017/8/29.
//  Copyright © 2017年 lemon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SKSocketHeader.h"

NS_ASSUME_NONNULL_BEGIN

@protocol SKWebSocketManagerDelegate <NSObject>

/**
 连接成功
 */
- (void)socketDidConnectToHost:(NSString *)host port:(uint16_t)port;

/**
 连接失败
 */
- (void)socketConnectFailueWithError:(NSError *)error;

@end

@interface SKWebSocketManager : NSObject

/* 连接状态 **/
@property (nonatomic, assign) ConnectStatus connectStatus;
/* 中断原因 **/
@property (nonatomic, assign) WebSocketOfflineStyle offlineStyle;

@property (nonatomic, weak) id <SKWebSocketManagerDelegate> delegate;

/**
 *  连接后是否自动开启心跳，默认为YES
 */
@property (nonatomic, assign) BOOL heartbeatEnabled;
/**
 *  断开连接后，是否自动重连，默认为YES
 */
@property (nonatomic, assign) BOOL autoReconnect;

@property (nonatomic, assign) NSInteger heartBeatSentCount;  // 发送心跳次数，用于重连

@property (nonatomic, assign) NSInteger reconnectionCount;  // 建连失败重连次数,默认为500次

/**
 *  开始自动重连后，首次重连时间间隔，默认为5秒，后面每常识重连10次增加5秒
 */
@property (nonatomic, assign) NSTimeInterval connectTimerInterval;


/*  ws://10.22.64.79:8888  **/
@property (nonatomic, copy) NSString  *socketHost;

+ (nullable SKWebSocketManager *)sharedInstance;

- (void)connect;

- (void)connectWithHost:(nonnull NSString *)host;

// Send a UTF8 String or Data.
- (void)sendData:(id)data;

- (void)reconnect:(nullable void(^)(bool success)) block;

- (void)disConnect;

/**
 *  重设心跳次数
 */
- (void)resetBeatCount;

@end
NS_ASSUME_NONNULL_END

