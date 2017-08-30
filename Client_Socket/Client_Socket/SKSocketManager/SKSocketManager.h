//
//  SKSocketManager.h
//  Client_Socket
//
//  Created by KUN on 2017/8/22.
//  Copyright © 2017年 lemon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SKSocketHeader.h"

NS_ASSUME_NONNULL_BEGIN

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
