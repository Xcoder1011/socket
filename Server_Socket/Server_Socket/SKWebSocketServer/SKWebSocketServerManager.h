//
//  SKWebSocketServerManager.h
//  Server_Socket
//
//  Created by KUN on 2017/8/22.
//  Copyright © 2017年 lemon. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SKSocketServerConnection;
@class GCDAsyncSocket;
@protocol SKWebSocketServerDelegate ;


@interface SKWebSocketServerManager : NSObject

/** 端口 */
@property (nonatomic, assign) uint16_t port;

/** 监听地址, 例如本机IP地址 */
@property (nonatomic, copy) NSString *listenAddress;

/** 已经连接的socket */
@property (nonatomic, strong, readonly) NSMutableArray *connections;

@property (nonatomic , weak) id<SKWebSocketServerDelegate>delegate;


+ (SKWebSocketServerManager *)sharedServerManager;

/**
 开始监听
 */
- (void)startAccept;

- (void)send:(id)object;

@end


@protocol SKWebSocketServerDelegate <NSObject>

- (void)webSocketServer:(SKWebSocketServerManager *)server didAcceptNewConnection:(GCDAsyncSocket *)newConnection;

- (void)webSocketServer:(SKWebSocketServerManager *)server clientDidDisconnect:(GCDAsyncSocket *)connection withError:(NSError *)err;

- (void)webSocketServer:(SKWebSocketServerManager *)server didReceiveData:(NSData *)data fromConnection:(GCDAsyncSocket *)connection;

- (void)webSocketServer:(SKWebSocketServerManager *)server couldNotParseRawData:(NSData *)data fromConnection:(GCDAsyncSocket *)connection withError:(NSError *)err;

@end
