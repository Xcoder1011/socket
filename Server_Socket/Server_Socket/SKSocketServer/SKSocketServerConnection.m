//
//  SKSocketServerConnection.m
//  Server_Socket
//
//  Created by KUN on 2017/8/22.
//  Copyright © 2017年 lemon. All rights reserved.
//

#import "SKSocketServerConnection.h"
#import "GCDAsyncSocket.h"

@interface SKSocketServerConnection () <GCDAsyncSocketDelegate>

@property (nonatomic, strong) GCDAsyncSocket *asyncSocket;
@property (nonatomic, strong) dispatch_queue_t socketQueue;
@end


@implementation SKSocketServerConnection

- (instancetype)initWithAsyncSocket:(GCDAsyncSocket *)aSocket configQueue:(dispatch_queue_t)queue {
    
    if (self = [super init]) {
        _socketQueue = queue;
        _asyncSocket = aSocket;
        [_asyncSocket setDelegate:self delegateQueue:_socketQueue];
    }
    return self;
}

- (void)start {
    
    NSString *host = [self.asyncSocket connectedHost];
    uint16_t port = [self.asyncSocket connectedPort];
    NSLog(@"SKSocketServerConnection start %@:%hu", host, port);
    
    __weak typeof(self) weakself = self;
    dispatch_async([self socketQueue], ^{
        @autoreleasepool {
            [weakself.asyncSocket readDataWithTimeout:-1 tag:0];
        }
    });
}

- (void)stop {
    
    __weak typeof(self) weakself = self;
    dispatch_async([self socketQueue], ^{
        @autoreleasepool {
            [weakself.asyncSocket disconnect];
        }
    });
}



#pragma mark -- GCDAsyncSocketDelegate


////////////////////////////////////////////////////////////////////////////////

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    
    // 2.2
    NSString *host = [self.asyncSocket connectedHost];
    UInt16 port = [self.asyncSocket connectedPort];
    NSLog(@"[%@:%hu] didReadData length: %lu ,tag :%ld", host, port, (unsigned long)data.length,tag);
    // [10.22.64.148:53223] didReadData length: 3 ,tag :0
    [sock writeData:data withTimeout:-1 tag:0];
    
    
    dispatch_async(self.socketQueue, ^{
        // 转为明文
        
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//        // 去除'\n'
        str  = [str stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        
        NSLog(@"server didReadData = %@",str);
  
    });
    
}


- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    
    // 3.
    NSString *host = [self.asyncSocket connectedHost];
    UInt16 port = [self.asyncSocket connectedPort];
    NSLog(@"[%@:%hu] didWriteDataWithTag :%ld", host, port, tag);
    // [10.22.64.148:53223] didWriteDataWithTag :0
    [sock readDataWithTimeout:-1 tag:tag];
    
}


////////////////////////////////////////////////////////////////////////////////



- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    DDLog(@"host = %@,port = %hu",host,port);
    
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToUrl:(NSURL *)url {
    DDLog(@"didConnectToUrl = %@",url);
}


- (void)socket:(GCDAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
    
    DDLog(@"partialLength = %ld ,tag = %ld",partialLength ,tag);
    
}


- (void)socket:(GCDAsyncSocket *)sock didWritePartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
    DDLog(@"partialLength = %ld ,tag = %ld",partialLength ,tag);
    
}


- (void)socketDidCloseReadStream:(GCDAsyncSocket *)sock {
    DDLog(@"socketDidCloseReadStream");
    
}


- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)err {
    
    // lost
    NSString *host = [self.asyncSocket connectedHost];
    UInt16 port = [self.asyncSocket connectedPort];
    NSLog(@"[%@:%hu] socketDidDisconnect: %@", host, port, err.description);
    [self.delegate didDisConnect:self withError:err];
    
}

- (void)socketDidSecure:(GCDAsyncSocket *)sock {
    DDLog(@"socketDidSecure");
    
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag elapsed:(NSTimeInterval)elapsed bytesDone:(NSUInteger)length
{
    //read time 15 second
    if (elapsed <= 15.0) {
        return 0.0;
    }
    
    return 0.0;
}


@end
