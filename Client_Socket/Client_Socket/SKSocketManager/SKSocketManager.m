//
//  SKSocketManager.m
//  Client_Socket
//
//  Created by KUN on 2017/8/22.
//  Copyright © 2017年 lemon. All rights reserved.
//

#import "SKSocketManager.h"
#import "GCDAsyncSocket.h"

#ifdef DEBUG
# define DDLog(format, ...) NSLog((@"[文件名:%s]" "[函数名:%s]" "[行号:%d]" format), __FILE__, __FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
# define DDLog(...);
#endif


@interface SKSocketManager () <GCDAsyncSocketDelegate>

@property (nonatomic, strong) GCDAsyncSocket   *tcpSocket;
@property (nonatomic, strong) dispatch_queue_t  socketQueue;

@end

@implementation SKSocketManager

+ (nullable SKSocketManager *)sharedInstance {
    static SKSocketManager *manager ;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        manager = [[self alloc] init];
    });
    return manager;
}

- (instancetype)init {
    
    if (self = [super init]) {
        
        _socketQueue = dispatch_queue_create("tcpSocketQueue", NULL);
        _tcpSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_socketQueue];
        
        self.connectStatus = ConnectStatus_UnConnected;
    }
    return self;
}


- (void)connect {

    [self connectWithIp:HOST port:PORT];
}

- (void)connectAutomatic:(void (^)())completion {

}

- (void)connectWithIp:(nonnull NSString * )ip port:(UInt16)port {

    NSError *error = nil;
    [_tcpSocket connectToHost:ip onPort:port error:&error];
    
    if (error) {
        NSLog(@"connect失败:%@",error);
        if (self.delegate) {
            [self.delegate socketConnectFailueWithError:error];
        }
        
    } else {
        NSLog(@"connect success on port %hu", [_tcpSocket localPort]);
    }
}


#pragma mark -- GCDAsyncSocketDelegate


- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    DDLog(@"host = %@,port = %d",host,port);
    if (self.delegate) {
        [self.delegate socketDidConnectToHost:host port:port];
    }
}


- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    
    DDLog(@"didReadData tag = %ld",tag);
    [sock readDataWithTimeout:-1 tag:tag];
    
}

- (void)socket:(GCDAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
    
    DDLog(@"partialLength = %ld ,tag = %ld",(unsigned long)partialLength ,tag);
    
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    
    DDLog(@"didWriteDataWithTag tag = %ld" ,tag);
    
    
}

- (void)socket:(GCDAsyncSocket *)sock didWritePartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
    DDLog(@"partialLength = %ld ,tag = %ld",(unsigned long)partialLength ,tag);
    
}


- (void)socketDidCloseReadStream:(GCDAsyncSocket *)sock {
    DDLog(@"socketDidCloseReadStream");
    
}


- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)err {
    DDLog(@"socketDidDisconnect");
    //    [self.connections removeObject:sock];
}

- (void)socketDidSecure:(GCDAsyncSocket *)sock {
    DDLog(@"socketDidSecure");
    
}



@end
