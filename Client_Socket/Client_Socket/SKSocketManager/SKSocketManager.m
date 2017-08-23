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

@property (nonatomic, strong) dispatch_queue_t  sendQueue;  // 发送数据串行队列
@property (nonatomic, strong) dispatch_queue_t  receiveQueue; // 接收数据串行队列
@property (nonatomic, strong) dispatch_queue_t  heartTimerSerialQueue;

@property (nonatomic, strong) dispatch_source_t  heartBeatTimer; // 心跳定时器
@property (nonatomic, assign) NSInteger heartBeatSentCount;

@property (nonatomic, strong) NSString *ip;
@property (nonatomic, assign) UInt16 port;

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
        _sendQueue = dispatch_queue_create("com.sendQueue", DISPATCH_QUEUE_SERIAL);
        _receiveQueue = dispatch_queue_create("com.receiveQueue", DISPATCH_QUEUE_SERIAL);

        _tcpSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_sendQueue];
        self.connectStatus = ConnectStatus_UnConnected;
    }
    return self;
}


- (void)connect {
    [self connectWithIp:HOST port:PORT];
}


- (void)connectWithIp:(nonnull NSString * )ip port:(UInt16)port {

    if (self.connectStatus != ConnectStatus_UnConnected) {
        NSLog(@"socket did connect, not need connect again!");
        return;
    }
    self.connectStatus = ConnectStatus_Connecting;
    self.ip = ip;
    self.port = port;
    
    NSError *error = nil;
    [_tcpSocket connectToHost:ip onPort:port error:&error];
    if (error) {
        NSLog(@"connect fail :%@",error);
        self.connectStatus = ConnectStatus_UnConnected;
        if (self.delegate) {
            [self.delegate socketConnectFailueWithError:error];
        }
        
    } else {
        NSLog(@"connect success on port %hu", [_tcpSocket localPort]);
    }
}


// Send a UTF8 String or Data.
- (void)sendData:(id)data {
    
    data = [data copy];
    dispatch_async(self.sendQueue, ^{
        
        if (self.tcpSocket == nil || self.tcpSocket.isDisconnected) { // 重新连接
            [self connectWithIp:self.ip port:self.port];
        }
        
        if ([data isKindOfClass:[NSString class]]) {
            
            NSData *requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
            [self.tcpSocket writeData:requestData withTimeout:TimeOut tag:0];
            [self.tcpSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:TimeOut maxLength:0 tag:0];
            
        } else if ([data isKindOfClass:[NSData class]]) {
            
            [self.tcpSocket writeData:data withTimeout:TimeOut tag:0];
            [self.tcpSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:TimeOut maxLength:0 tag:0];
            
        } else {
            assert(NO);
        }
    });
}

- (void)disConnect {
    [self.tcpSocket disconnect];
    self.tcpSocket = nil;
    self.sendQueue = nil;
    self.receiveQueue = nil;
    self.connectStatus = ConnectStatus_UnConnected;
    
    _heartBeatSentCount = 0;
    // 关闭心跳定时器
    [self invalidate];
}

- (void)sendHeartBeat {

    self.connectStatus = ConnectStatus_Connected;
    // 心跳开启
    [self fire];
}

- (dispatch_source_t)heartBeatTimer {

    if (!_heartBeatTimer) {
        _heartTimerSerialQueue = dispatch_queue_create("com.sktimer.targetSerialQueue", DISPATCH_QUEUE_SERIAL);
        _heartBeatTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _heartTimerSerialQueue);
        // 1.开始时间
        dispatch_time_t start = dispatch_time(DISPATCH_TIME_NOW, 0.0 * NSEC_PER_SEC);
        // 2.心跳频率
        int64_t intervalInSeconds = (int64_t)(HeartBeatRate * NSEC_PER_SEC);
        // 3.误差（时间精度）
        int64_t toleranceInSeconds = (int64_t)(0 * NSEC_PER_SEC);
        dispatch_source_set_timer(_heartBeatTimer, start, intervalInSeconds, toleranceInSeconds);
        
        dispatch_source_set_event_handler(_heartBeatTimer, ^{
            
            _heartBeatSentCount ++;
            
            if (_heartBeatSentCount > HeartBeatMaxLostCount) { // 超过3次未收到服务器心跳 , 置为未连接状态
                self.connectStatus = ConnectStatus_UnConnected;
                
            } else {
                //发送心跳
                NSData *beatData = [[NSData alloc]initWithBase64EncodedString:[HeartBeatIdentifier stringByAppendingString:@"\n"] options:NSDataBase64DecodingIgnoreUnknownCharacters];
                [self.tcpSocket writeData:beatData withTimeout:-1 tag:9999];
                NSLog(@"heart beat send ...");
            }
        });
    }
    return _heartBeatTimer;
}


- (void)fire {
    if(self.heartBeatTimer) {
        dispatch_resume(self.heartBeatTimer);
    }
}

- (void)invalidate {
   
    if (self.heartBeatTimer ) {
        __block dispatch_source_t timer = self.heartBeatTimer;
        dispatch_async(self.heartTimerSerialQueue, ^{
            dispatch_source_cancel(timer);
            timer = nil;
        });
    }
}

#pragma mark -- GCDAsyncSocketDelegate


- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    DDLog(@"Connect To Host = %@,port = %d",host,port);
    
//    [self.tcpSocket performBlock:^{
//         [self.tcpSocket enableBackgroundingOnSocket];
//    }];
    
    dispatch_async(self.receiveQueue, ^{
        if (self.delegate) {
            [self.delegate socketDidConnectToHost:host port:port];
        }
    });
}

// 接收到消息
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    
    DDLog(@"didReadData tag = %ld",tag);
    
    dispatch_async(self.receiveQueue, ^{
        // 转为明文
        NSString *secretStr  = [data base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
        // 去除'\n'
        secretStr  = [secretStr stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        
        NSLog(@"didReadData secretStr = %@",secretStr);
        
        //开始发送心跳
//        [self sendHeartBeat];
    });
    
    [self.tcpSocket readDataWithTimeout:TimeOut tag:tag];

    
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
    dispatch_async(self.receiveQueue, ^{
        self.tcpSocket = nil;
        self.sendQueue = nil;
        self.connectStatus = ConnectStatus_UnConnected;
    });

}

- (void)socketDidSecure:(GCDAsyncSocket *)sock {
    DDLog(@"socketDidSecure");
    
}



@end
