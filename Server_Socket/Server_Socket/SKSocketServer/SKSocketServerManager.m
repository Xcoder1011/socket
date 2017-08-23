//
//  SKSocketServerManager.m
//  Server_Socket
//
//  Created by KUN on 2017/8/22.
//  Copyright © 2017年 lemon. All rights reserved.
//

#import "SKSocketServerManager.h"
#import "SKSocketServerConnection.h"
#import "GCDAsyncSocket.h"

@interface SKSocketServerManager () <GCDAsyncSocketDelegate, SKSocketServerConnectionDelegate>

@property (nonatomic, strong) GCDAsyncSocket *tcpSocket;

@property (nonatomic, strong) dispatch_queue_t socketQueue;

@property (nonatomic, strong, readwrite) NSMutableArray <SKSocketServerConnection *> *connections;

@end


@implementation SKSocketServerManager

+ (SKSocketServerManager *)sharedServerManager {
    
    static SKSocketServerManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[SKSocketServerManager alloc] init];
    });
    return manager;
}

- (instancetype)init
{
    if (self = [super init]) {
        
        _socketQueue = dispatch_queue_create("tcpSocketQueue", NULL);
        _tcpSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_socketQueue];
        
        _connections = [[NSMutableArray alloc] initWithCapacity:1];
        
    }
    return self;
}

- (void)startAccept {
    
    NSError *error = nil;
    [_tcpSocket acceptOnInterface:self.listenAddress port:self.port error:&error];
    
    if (error) {
        NSLog(@"监听失败:%@",error);
        
    } else {
        NSLog(@"监听成功:%@",error);
        NSLog(@"tcp server started on port %hu", [_tcpSocket localPort]);
        
    }
}


#pragma mark -- GCDAsyncSocketDelegate


- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket;{
    DDLog(@"didAcceptNewSocket");
    
    @synchronized (_connections) {
        
        SKSocketServerConnection *connection = [[SKSocketServerConnection alloc] initWithAsyncSocket:newSocket configQueue:self.socketQueue];
        connection.delegate = self;
        [_connections addObject:connection];
        
        [connection start];
    }
    
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    DDLog(@"host = %@,port = %d",host,port);
    
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToUrl:(NSURL *)url {
    DDLog(@"didConnectToUrl = %@",url);
}


- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    
    DDLog(@"didReadData tag = %ld",tag);
    [sock readDataWithTimeout:-1 tag:tag];
    
}

- (void)socket:(GCDAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
    
    DDLog(@"partialLength = %ld ,tag = %ld",partialLength ,tag);
    
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    
    DDLog(@"didWriteDataWithTag tag = %ld" ,tag);
    
    
}

- (void)socket:(GCDAsyncSocket *)sock didWritePartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
    DDLog(@"partialLength = %ld ,tag = %ld",partialLength ,tag);
    
}


- (void)socketDidCloseReadStream:(GCDAsyncSocket *)sock {
    DDLog(@"socketDidCloseReadStream");
    
}


- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)err {
    DDLog(@"socketDidDisconnect");
    //每当有客户端断开连接的时候，客户端数组移除该socket
//    [self.clientSockets removeObject:sock];
}

- (void)socketDidSecure:(GCDAsyncSocket *)sock {
    DDLog(@"socketDidSecure");
    
}


#pragma mark -- SKServerSocketConnectionDelegate

- (void)didDisConnect:(SKSocketServerConnection *)con withError:(NSError *)error {
    
    @synchronized(_connections) {
        [_connections removeObject:con];
    }
}

@end
