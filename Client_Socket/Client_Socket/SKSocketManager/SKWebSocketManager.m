//
//  SKWebSocketManager.m
//  Client_Socket
//
//  Created by KUN on 2017/8/29.
//  Copyright © 2017年 lemon. All rights reserved.
//

#import "SKWebSocketManager.h"
#import <SocketRocket/SocketRocket.h>
#import "SKMulticastDelegate.h"

@interface SKWebSocketManager () <SRWebSocketDelegate>
{
    void *websocketQueueTag;
    NSMutableArray *_delegateNodes;
    SKMulticastDelegate <SKWebSocketManagerDelegate> *_multicastDelegate;
}

@property (nonatomic, strong) SRWebSocket   *webSocket;
@property (nonatomic, strong) dispatch_queue_t  websocketQueue;
@property (nonatomic, strong) dispatch_queue_t  sendQueue;  // 发送数据串行队列
@property (nonatomic, strong) dispatch_queue_t  receiveQueue; // 接收数据串行队列

@property (nonatomic, strong) NSTimer *heartTimer;  // 心跳定时器
@property (nonatomic, strong) NSTimer *reconnectTimer;  // 重连定时器

@property (nonatomic, strong) NSString *ip;
@property (nonatomic, assign) UInt16 port;
@property (nonatomic, copy) void(^reconnectBlock)(bool success);

@end


@implementation SKWebSocketManager

+ (nullable SKWebSocketManager *)sharedInstance {
    static SKWebSocketManager *manager ;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        manager = [[self alloc] init];
    });
    return manager;
}

- (instancetype)init {
    if (self = [super init]) {
        websocketQueueTag = &websocketQueueTag;
        _websocketQueue = dispatch_queue_create("com.websocketQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_websocketQueue, websocketQueueTag, websocketQueueTag, NULL);
        _sendQueue = dispatch_queue_create("com.sendQueue", DISPATCH_QUEUE_SERIAL);
        _receiveQueue = dispatch_queue_create("com.receiveQueue", DISPATCH_QUEUE_SERIAL);
        
        self.connectStatus = ConnectStatus_UnConnected;
        _heartbeatEnabled = YES;
        _autoReconnect = YES;
        _multicastDelegate = (SKMulticastDelegate <SKWebSocketManagerDelegate> *)[[SKMulticastDelegate alloc] init];
        _delegateNodes = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)connect {
    
    [self connectWithHost:self.socketHost];
}

- (void)connectWithHost:(nonnull NSString *)host {
    
    if (self.connectStatus != ConnectStatus_UnConnected) {
        NSLog(@"socket did connect, not need connect again!");
        return;
    }
    self.connectStatus = ConnectStatus_Connecting;
    self.socketHost = host;
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc]initWithURL:[NSURL URLWithString:host] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10];
    [request addValue:@"1234567" forHTTPHeaderField:@"token"];
    [request addValue:@"13" forHTTPHeaderField:@"build"];
    [request addValue:@"1.0" forHTTPHeaderField:@"version"];
    [request addValue:@"ios" forHTTPHeaderField:@"osType"];
    self.webSocket = [[SRWebSocket alloc]initWithURLRequest:request];
    //self.webSocket = [[SRWebSocket alloc]initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:host]]];
    self.webSocket.delegate = self;
    [self.webSocket open];
    
}

- (void)reconnect:(nullable void(^)(bool success))block {
    
    [self disConnect];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc]initWithURL:[NSURL URLWithString:self.socketHost] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10];
    
    [request addValue:@"1234567" forHTTPHeaderField:@"token"];
    [request addValue:@"13" forHTTPHeaderField:@"build"];
    [request addValue:@"1.0" forHTTPHeaderField:@"version"];
    [request addValue:@"ios" forHTTPHeaderField:@"osType"];
    self.webSocket = [[SRWebSocket alloc]initWithURLRequest:request];
    // _webSocket = [[SRWebSocket alloc]initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:self.socketHost]]];
    _webSocket.delegate = self;
    [_webSocket open];
    self.connectStatus = ConnectStatus_Connecting;
    
    if (block) {
        self.reconnectBlock = [block copy];
    }
}


// Send a UTF8 String or Data.
- (void)sendData:(id)data {
    
    __weak typeof(self) weakself = self;
    data = [data copy];
    dispatch_async(self.sendQueue, ^{
        __strong typeof(weakself) self = weakself;
        
        if (self.webSocket == nil || self.webSocket.readyState == SR_CLOSED || self.webSocket.readyState == SR_CLOSING) { // 重新连接
            [self reconnect:^(bool success) {
                [weakself sendData:data];
            }];
            return ;
        }
        
        if (self.webSocket == nil || self.webSocket.readyState == SR_CONNECTING) { // 重新连接
            NSLog(@"正在连接中....");
            [self reconnect:^(bool success) {
                [weakself sendData:data];
            }];
            return ;
        }
        
        if (self.webSocket.readyState != SR_OPEN) {
            return;
        }
        
        if ([data isKindOfClass:[NSString class]]) {
            
            NSData *requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
            [self.webSocket send:requestData];
            
        } else if ([data isKindOfClass:[NSData class]]) {
            
            [self.webSocket send:data];
            
        } else {
            assert(NO);
        }
    });
}

- (void)sendDataWithParam:(NSDictionary *)param block:(nullable void(^)(bool success))result {
    
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:param options:NSJSONWritingPrettyPrinted error:&error];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    if (error) {
        if (result) {
            result(NO);
        }
        return;
    }
    
    [self sendData:jsonString];
    if (result) {
        result(YES);
    }
}

/**
 主动断开连接
 */
- (void)executeDisConnect {
    
    self.offlineStyle = WebSocketOfflineStyle_User;
    [self disConnect];
}

/**
 网络或者服务器原因 中断
 */
- (void)serverInterruption {
    
    self.offlineStyle = WebSocketOfflineStyle_NetWork;
    [self disConnect];
}

- (void)disConnect {
    
    if (nil == self.webSocket) {
        return;
    }
    [self.webSocket close];
    self.webSocket = nil;
    self.connectStatus = ConnectStatus_UnConnected;
    _heartBeatSentCount = 0;
    [self stopHeartbeatTimer];
}


#pragma mark -- ❤️心跳相关

- (void)startHeartbeatTimer:(NSTimeInterval)interval
{
    NSTimeInterval minInterval = MAX(5, interval);
    [self stopHeartbeatTimer];
    self.heartTimer = [NSTimer scheduledTimerWithTimeInterval:minInterval target:self selector:@selector(heartTimerAct) userInfo:nil repeats:YES];
}

- (void)stopHeartbeatTimer
{
    if (self.heartTimer) {
        [self.heartTimer invalidate];
        self.heartTimer = nil;
    }
}

- (void)heartTimerAct {
    
    _heartBeatSentCount ++;
    if (_heartBeatSentCount >= HeartBeatMaxLostCount) { // 超过3次未收到服务器心跳 , 置为未连接状态
        self.reconnectionCount = 0;
        [self serverInterruption];
        
    } else {
        //发送心跳
        [self sendDataWithParam:@{@"data_type":@3} block:nil];
        NSLog(@"heart beat send ...");
    }
}

- (void)resetBeatCount {
    self.heartBeatSentCount = 0;
}


#pragma mark -- reconnect timer

- (void)startConnectTimer:(NSTimeInterval)interval
{
    NSTimeInterval minInterval = MAX(5, interval);
    
    [self stopConnectTimer];
    
    if (!self.reconnectTimer) {
        
        self.reconnectTimer = [NSTimer scheduledTimerWithTimeInterval:minInterval
                                                               target:self
                                                             selector:@selector(reconnectTimerAct)
                                                             userInfo:nil
                                                              repeats:NO];
        [[NSRunLoop mainRunLoop] addTimer:self.reconnectTimer forMode:NSRunLoopCommonModes];
    }
    self.reconnectionCount++;
    
}

- (void)stopConnectTimer
{
    if (_reconnectTimer) {
        [_reconnectTimer invalidate];
        _reconnectTimer = nil;
    }
}

- (void)reconnectTimerAct {
    
    if (!self.autoReconnect) {
        [self stopConnectTimer];
        return;
    }
    
    //重连次数超过最大尝试次数，停止
    if (self.reconnectionCount > kConnectMaxCount) {
        self.reconnectionCount = 0;
        [self stopConnectTimer];
        [self stopHeartbeatTimer];
        [self serverInterruption];
        NSLog(@"重连次数超过最大尝试次数");
        dispatch_async(dispatch_get_main_queue(), ^{
            [_multicastDelegate webSocketdidReconnectCount:self.reconnectionCount exceedMaxRecordCount:YES];
        });
        
        return;
    }
    
    NSLog(@"第%ld次重新连接。。",self.reconnectionCount);
    dispatch_async(dispatch_get_main_queue(), ^{
        [_multicastDelegate webSocketdidReconnectCount:self.reconnectionCount exceedMaxRecordCount:NO];
    });
    
    /*
     // 重连时间策略 1
     if (self.reconnectionCount % 10 == 0) {
     _connectTimerInterval += kConnectTimerInterval;
     [self startConnectTimer:_connectTimerInterval];
     }
     // 重连时间策略 2
     _connectTimerInterval *= 2;
     */
    
    [self openConnection];
}


- (void)openConnection
{
    if ([self isConnected]) {
        return;
    }
    [self reconnect:nil];
}


- (BOOL)isConnected
{
    __block BOOL result = NO;
    __weak typeof(self) weakSelf = self;
    
    dispatch_sync([self websocketQueue], ^{
        @autoreleasepool {
            result = weakSelf.connectStatus  == ConnectStatus_Connected ? YES : NO;
        }
    });
    return result;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)addDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue
{
    if (delegate == nil) return;
    if (delegateQueue == NULL) return;
    
    dispatch_block_t block = ^{
        [_multicastDelegate addDelegate:delegate delegateQueue:delegateQueue];
    };
    
    if (dispatch_get_specific(websocketQueueTag))
        block();
    else
        dispatch_async(_websocketQueue, block);
}

- (void)removeDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue
{
    // Synchronous operation
    
    dispatch_block_t block = ^{
        [_multicastDelegate removeDelegate:delegate delegateQueue:delegateQueue];
    };
    
    if (dispatch_get_specific(websocketQueueTag))
        block();
    else
        dispatch_sync(_websocketQueue, block);
}

- (void)removeDelegate:(id)delegate
{
    // Synchronous operation
    
    dispatch_block_t block = ^{
        [_multicastDelegate removeDelegate:delegate];
    };
    if (dispatch_get_specific(websocketQueueTag))
        block();
    else
        dispatch_sync(_websocketQueue, block);
}


///--------------------------------------
#pragma mark - SRWebSocketDelegate
///--------------------------------------

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message{
    
    dispatch_async(self.receiveQueue, ^{
        [self resetBeatCount];
        dispatch_async(dispatch_get_main_queue(), ^{
            [_multicastDelegate webSocketdidReceiveMessage:message];
        });
    });
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    NSLog(@"Websocket Connected");
    if (self.reconnectBlock) {
        self.reconnectBlock(true);
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [_multicastDelegate webSocketDidConnectToSocketHost:self.socketHost];
    });
    self.reconnectionCount = 0;
    [self stopConnectTimer];
    self.connectStatus = ConnectStatus_Connected;
    if (self.heartbeatEnabled) {
        __weak __typeof(self) weakself = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakself startHeartbeatTimer:HeartBeatRate];
        });
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error;
{
    self.connectStatus = ConnectStatus_UnConnected;
    dispatch_async(dispatch_get_main_queue(), ^{
        [_multicastDelegate webSocketConnectFailueWithError:error];
    });
    // 服务器掉线，重连
    if (self.autoReconnect) {
        __weak __typeof(self) weakself = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, _connectTimerInterval), dispatch_get_main_queue(), ^{
            [weakself startConnectTimer:weakself.connectTimerInterval];
        });
    }
}

// 长连接主动关闭
- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean{
    NSLog(@"WebSocket closed code = %ld ,reason = %@",code,reason);
    self.connectStatus = ConnectStatus_UnConnected;
    [self executeDisConnect];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [_multicastDelegate webSocketdidCloseWithCode:code reason:self.offlineStyle];
    });
}

- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload {
    NSLog(@"WebSocket received pong");
    _heartBeatSentCount = 0;
}

// Return YES to convert messages sent as Text to an NSString. Return NO to skip NSData -> NSString conversion for Text messages. Defaults to YES.
- (BOOL)webSocketShouldConvertTextFrameToString:(SRWebSocket *)webSocket {
    return YES;
}


@end
