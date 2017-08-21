//
//  SKServerSocketManager.h
//  Server_Socket
//
//  Created by KUN on 2017/8/21.
//  Copyright © 2017年 lemon. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface SKServerSocketManager : NSObject

/** 端口 */
@property (nonatomic, assign) uint16_t port;

/** 监听地址, 例如本机IP地址 */
@property (nonatomic, copy) NSString *listenAddress;

/** 已经连接的socket */
@property (nonatomic, strong, readonly) NSMutableArray *connectedSockets;

+ (SKServerSocketManager *)sharedServerManager;


/**
 开始监听
 */
- (void)startAccept;

@end
