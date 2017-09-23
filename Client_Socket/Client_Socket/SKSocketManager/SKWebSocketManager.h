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

@optional
/**
 连接成功
 */
- (void)webSocketDidConnectToSocketHost:(NSString *)host;

/**
 连接失败
 */
- (void)webSocketConnectFailueWithError:(NSError *)error;


- (void)webSocketdidReceiveMessage:(id)message;

/**
 socket 断开连接
 */
- (void)webSocketdidCloseWithCode:(NSInteger)code reason:(WebSocketOfflineStyle)offlineStyle;


/**
 socket 自动重连
 
 @param reconectCount 正在重连次数
 @param exceedMaxRecordCount 是否超过最大重连次数
 */
- (void)webSocketdidReconnectCount:(NSInteger)reconectCount exceedMaxRecordCount:(BOOL)exceedMaxRecordCount;


@end

@interface SKWebSocketManager : NSObject

/* 连接状态 **/
@property (nonatomic, assign) ConnectStatus connectStatus;
/* 中断原因 **/
@property (nonatomic, assign) WebSocketOfflineStyle offlineStyle;

@property (nonatomic, weak) id <SKWebSocketManagerDelegate> delegate;

- (void)addDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue;
- (void)removeDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue;
- (void)removeDelegate:(id)delegate;

/**
 *  连接后是否自动开启心跳，默认为YES
 */
@property (nonatomic, assign) BOOL heartbeatEnabled;
/**
 *  断开连接后，是否自动重连，默认为YES
 */
@property (nonatomic, assign) BOOL autoReconnect;

@property (nonatomic, assign) NSInteger heartBeatSentCount;  // 发送心跳次数，用于重连

@property (nonatomic, assign) NSInteger reconnectionCount;  // 建连失败重连次数5

/**
 *  开始自动重连后，首次重连时间间隔，默认为3秒，后面每尝试重连10次增加3秒
 */
@property (nonatomic, assign) NSTimeInterval connectTimerInterval;


/*  ws://10.22.64.79:8888  **/
@property (nonatomic, copy) NSString  *socketHost;

+ (nullable SKWebSocketManager *)sharedInstance;

- (void)connect;

- (void)connectWithHost:(nonnull NSString *)host;

// Send a UTF8 String or Data.
- (void)sendData:(id)data;

- (void)sendDataWithParam:(NSDictionary *)param block:(nullable void(^)(bool success))result;

- (void)reconnect:(nullable void(^)(bool success)) block;

/**
 主动断开连接
 */
- (void)executeDisConnect;

/**
 *  重设心跳次数
 */
- (void)resetBeatCount;

@end
NS_ASSUME_NONNULL_END

