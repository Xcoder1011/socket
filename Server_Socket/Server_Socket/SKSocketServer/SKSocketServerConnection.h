//
//  SKSocketServerConnection.h
//  Server_Socket
//
//  Created by KUN on 2017/8/22.
//  Copyright © 2017年 lemon. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifdef DEBUG
# define DDLog(format, ...) NSLog((@"[文件名:%s]" "[函数名:%s]" "[行号:%d]" format), __FILE__, __FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
# define DDLog(...);
#endif

@class GCDAsyncSocket;
@class SKSocketServerConnection;

@protocol SKSocketServerConnectionDelegate <NSObject>

- (void)didDisConnect:(SKSocketServerConnection *)con withError:(NSError *)error;

@end


@interface SKSocketServerConnection : NSObject

@property (nonatomic , weak) id<SKSocketServerConnectionDelegate>delegate;

- (instancetype)initWithAsyncSocket:(GCDAsyncSocket *)aSocket configQueue:(dispatch_queue_t)queue;

- (void)start;
- (void)stop;


@end
