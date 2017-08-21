//
//  SKServerSocketManager.m
//  Server_Socket
//
//  Created by KUN on 2017/8/21.
//  Copyright © 2017年 lemon. All rights reserved.
//

#import "SKServerSocketManager.h"
#import "GCDAsyncSocket.h"

@interface SKServerSocketManager () <GCDAsyncSocketDelegate>

@property (nonatomic, strong) GCDAsyncSocket *tcpSocket;

@property (nonatomic, strong) dispatch_queue_t socketQueue;

@property (nonatomic, strong, readwrite) NSMutableArray *connectedSockets;

@end


@implementation SKServerSocketManager

+ (SKServerSocketManager *)sharedServerManager {
    
    static SKServerSocketManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[SKServerSocketManager alloc] init];
    });
    return manager;
}

- (instancetype)init
{
    if (self = [super init]) {
        
        _socketQueue = dispatch_queue_create("tcpSocketQueue", NULL);
        _tcpSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_socketQueue];
      
        _connectedSockets = [[NSMutableArray alloc] initWithCapacity:1];

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
    }
}


#pragma mark -- GCDAsyncSocketDelegate

- (nullable dispatch_queue_t)newSocketQueueForConnectionFromAddress:(NSData *)address onSocket:(GCDAsyncSocket *)sock {

    DDLog(@"newSocketQueueForConnectionFromAddress");
    return _socketQueue;
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket;{
    DDLog(@"didAcceptNewSocket");
    
    [self.connectedSockets addObject:newSocket];
    [newSocket readDataWithTimeout:-1 tag:0];
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
    
    [self.connectedSockets removeObject:sock];
}

- (void)socketDidSecure:(GCDAsyncSocket *)sock {
    DDLog(@"socketDidSecure");

}

- (void)socket:(GCDAsyncSocket *)sock didReceiveTrust:(SecTrustRef)trust
completionHandler:(void (^)(BOOL shouldTrustPeer))completionHandler {

    DDLog(@"didReceiveTrust");
}


@end
