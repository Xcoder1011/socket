//
//  SKSocketManager.h
//  Client_Socket
//
//  Created by KUN on 2017/8/22.
//  Copyright © 2017年 lemon. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#if DEBUG
static NSString * HOST = @"10.22.64.148";
static const int PORT = 8888;
#else
static NSString * HOST = @"10.22.64.148";
static const int PORT = 7070;
#endif

static NSTimeInterval TimeOut = -1;        // 超时时间, 超时会关闭 socket
static NSTimeInterval HeartBeatRate = 1;   // 💖心跳频率
static NSInteger  HeartBeatMaxLostCount = 3;   // 最大心跳丢失数
static NSString  *HeartBeatIdentifier = @"HeartBeatIdentifier";   // 心跳标识


typedef enum : NSUInteger {
    
    ConnectStatus_UnConnected  = 0,  //未连接
    ConnectStatus_Connected    = 1,  //已连接
    ConnectStatus_Connecting  = 2,  //连接中
    
} ConnectStatus;

@class SKSocketManager;
@protocol SKSocketManagerDelegate <NSObject>

/**
 连接成功
 */
- (void)socketDidConnectToHost:(NSString *)host port:(uint16_t)port;

/**
 连接失败
 */
- (void)socketConnectFailueWithError:(NSError *)error;

@end

@interface SKSocketManager : NSObject

/* 连接状态 **/
@property (nonatomic, assign) ConnectStatus connectStatus;

@property (nonatomic, weak) id <SKSocketManagerDelegate> delegate;

+ (nullable SKSocketManager *)sharedInstance;

- (void)connect;

- (void)connectWithIp:(nonnull NSString * )ip port:(UInt16)port;

// Send a UTF8 String or Data.
- (void)sendData:(id)data;

- (void)disConnect;


@end
NS_ASSUME_NONNULL_END
