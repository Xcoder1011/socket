//
//  SKSocketServerManager.h
//  Server_Socket
//
//  Created by KUN on 2017/8/22.
//  Copyright © 2017年 lemon. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SKSocketServerConnection;
@interface SKSocketServerManager : NSObject

/** 端口 */
@property (nonatomic, assign) uint16_t port;

/** 监听地址, 例如本机IP地址 */
@property (nonatomic, copy) NSString *listenAddress;

/** 已经连接的socket */
@property (nonatomic, strong, readonly) NSMutableArray <SKSocketServerConnection *> *connections;

+ (SKSocketServerManager *)sharedServerManager;


/**
 开始监听
 */
- (void)startAccept;

@end
