//
//  SKWebSocketManager.m
//  Client_Socket
//
//  Created by KUN on 2017/8/29.
//  Copyright © 2017年 lemon. All rights reserved.
//

#import "SKWebSocketManager.h"
#import <SocketRocket/SocketRocket.h>

@interface SKWebSocketManager () <SRWebSocketDelegate>

@property (nonatomic, strong) SRWebSocket   *webSocket;

@property (nonatomic, strong) dispatch_queue_t  sendQueue;  // 发送数据串行队列
@property (nonatomic, strong) dispatch_queue_t  receiveQueue; // 接收数据串行队列
@property (nonatomic, strong) dispatch_queue_t  heartTimerSerialQueue;

@property (nonatomic, strong) dispatch_source_t  heartBeatTimer;

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
        _sendQueue = dispatch_queue_create("com.sendQueue", DISPATCH_QUEUE_SERIAL);
        _receiveQueue = dispatch_queue_create("com.receiveQueue", DISPATCH_QUEUE_SERIAL);
        self.connectStatus = ConnectStatus_UnConnected;
        _heartbeatEnabled = YES;
        _autoReconnect = YES;
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
    
    self.webSocket = [[SRWebSocket alloc]initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:host]]];

    self.webSocket.delegate = self;
    [self.webSocket open];
    
    self.connectStatus = ConnectStatus_Connecting;

}

- (void)reconnect:(nullable void(^)(bool success))block {

//    _webSocket.delegate = nil;
//    [_webSocket close];
    
    [self disConnect];
    
    _webSocket = [[SRWebSocket alloc]initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:self.socketHost]]];
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
        
        if (self.webSocket == nil || self.webSocket.readyState == SR_CLOSED || self.webSocket.readyState == SR_CLOSING) { // 重新连接
            
            [self reconnect:^(bool success) {
               
                [weakself sendData:data];
            }];
        }
        
        if (self.webSocket == nil || self.webSocket.readyState == SR_CONNECTING) { // 重新连接
            return ;
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

- (void)disConnect {
    
    __weak typeof(self) weakself = self;

    dispatch_async(self.receiveQueue, ^{
        @autoreleasepool {
           
            if (nil == weakself.webSocket) {
                return;
            }
            
            [weakself.webSocket close];
            weakself.webSocket = nil;
//            weakself.sendQueue = nil;
//            weakself.receiveQueue = nil;
            weakself.connectStatus = ConnectStatus_UnConnected;
            weakself.offlineStyle = WebSocketOfflineStyle_User;
            _heartBeatSentCount = 0;
            // 关闭心跳定时器
            [weakself invalidate];
        }
    });
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
    if (_heartBeatSentCount >= HeartBeatMaxLostCount) { // 超过6次未收到服务器心跳 , 置为未连接状态
        self.reconnectionCount = -1;
        self.connectStatus = ConnectStatus_UnConnected;
        
        //[self disConnect];
        
    } else {
        
        //发送心跳
        NSData *beatData = [[HeartBeatIdentifier stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
        [self.webSocket sendPing:beatData];
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
        [self stopConnectTimer];
        return;
    }
    
    self.reconnectionCount ++;
    
    //重连时间策略
    if (self.reconnectionCount % 10 == 0) {
        _connectTimerInterval += kConnectTimerInterval;
        [self startConnectTimer:_connectTimerInterval];
    }
    
    if ([self isConnected]) {
        return;
    }
    [self openConnection];
}


- (void)openConnection
{
    if ([self isConnected]) {
        return;
    }
    [self disConnect];
    
    [self reconnect:nil];
}


- (BOOL)isConnected
{
    __block BOOL result = NO;
    __weak typeof(self) weakSelf = self;
    
    dispatch_sync([self receiveQueue], ^{
        @autoreleasepool {
            result = weakSelf.connectStatus  == ConnectStatus_Connected ? YES : NO;
        }
    });
    return result;
}


#pragma mark -- Depracted

- (dispatch_source_t)heartBeatTimer {
    
    if (!_heartBeatTimer) {
        _heartTimerSerialQueue = dispatch_queue_create("com.sktimer.targetSerialQueue", DISPATCH_QUEUE_SERIAL);
        _heartBeatTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _heartTimerSerialQueue);
        // 1.开始时间
        dispatch_time_t start = dispatch_time(DISPATCH_TIME_NOW, 0.0 * NSEC_PER_SEC);
        // 2.心跳频率
        NSTimeInterval minInterval = MAX(5, HeartBeatRate);
        int64_t intervalInSeconds = (int64_t)(minInterval * NSEC_PER_SEC);
        // 3.误差（时间精度）
        int64_t toleranceInSeconds = (int64_t)(0 * NSEC_PER_SEC);
        dispatch_source_set_timer(_heartBeatTimer, start, intervalInSeconds, toleranceInSeconds);
        
        dispatch_source_set_event_handler(_heartBeatTimer, ^{
            
            _heartBeatSentCount ++;
            
            if (_heartBeatSentCount >= HeartBeatMaxLostCount) { // 超过10次未收到服务器心跳 , 置为未连接状态
                self.reconnectionCount = -1;
                [self disConnect];
                
            } else {
                //发送心跳
                NSData *beatData = [[HeartBeatIdentifier stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
                [self.webSocket sendPing:beatData];
                NSLog(@"heart beat send ...");
            }
        });
    }
    return _heartBeatTimer;
}

// 开启心跳
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

- (void)sendHeartBeat {
    
    self.reconnectionCount = 0;
    self.connectStatus = ConnectStatus_Connected;
    self.connectTimerInterval = kConnectTimerInterval;
    // 心跳开启
    [self fire];
}


///--------------------------------------
#pragma mark - SRWebSocketDelegate
///--------------------------------------


- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message{

    NSLog(@"Received \"%@\"", message);
    
    dispatch_async(self.receiveQueue, ^{
        
        NSString *receivedStr = message;
        
        NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *messageDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
        NSLog(@"didReadData messageDict = %@",messageDict);

        // 去除'\n'
        receivedStr  = [receivedStr stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        NSLog(@"didReadData receivedStr = %@",receivedStr);
        
        _heartBeatTimer = 0;
        
        /*
        2017-08-30 16:23:15.579 Client_Socket[18495:3710209] Websocket Connected
        2017-08-30 16:23:15.579 Client_Socket[18495:3710209] Received "{'client_id':'7f0000010a8c0000000f'}"
        2017-08-30 16:23:15.592 Client_Socket[18495:3710631] didReadData messageDict = (null)
        2017-08-30 16:23:15.592 Client_Socket[18495:3710631] didReadData receivedStr = {'client_id':'7f0000010a8c0000000f'}
        2017-08-30 16:23:35.184 Client_Socket[18495:3710209] Received "{"type":"ping"}"
        2017-08-30 16:23:35.184 Client_Socket[18495:3710632] didReadData messageDict = {
            type = ping;
        }
        2017-08-30 16:23:35.185 Client_Socket[18495:3710632] didReadData receivedStr = {"type":"ping"}
        2017-08-30 16:23:45.189 Client_Socket[18495:3710209] Received "{"type":"ping"}"
        2017-08-30 16:23:45.189 Client_Socket[18495:3710632] didReadData messageDict = {
            type = ping;
        }
        2017-08-30 16:23:45.189 Client_Socket[18495:3710632] didReadData receivedStr = {"type":"ping"}
        2017-08-30 16:23:55.199 Client_Socket[18495:3710209] Received "{"type":"ping"}"
        2017-08-30 16:23:55.200 Client_Socket[18495:3710632] didReadData messageDict = {
            type = ping;
        }
        
        */
    });
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    NSLog(@"Websocket Connected");
    if (self.reconnectBlock) {
        self.reconnectBlock(true);
    }
    
    if (self.heartbeatEnabled) {
        __weak __typeof(self) weakself = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakself invalidate];
            [weakself startHeartbeatTimer:HeartBeatRate];
        });
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error;
{
    NSLog(@":( Websocket Failed With Error %@", error);
    if (self.delegate) {
        [self.delegate socketConnectFailueWithError:error];
    }
    
    NSLog(@"连接失败");
    if (self.offlineStyle == WebSocketOfflineStyle_NetWork) {
        // 服务器掉线，重连
        
        [self performSelector:@selector(reconnect:) withObject:nil afterDelay:2];
        
    }else if (self.offlineStyle == WebSocketOfflineStyle_User) {
        // 由用户主动断开，不进行重连
//        _webSocket = nil;
        [self disConnect];
        return;
    }
}


- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean{
    NSLog(@"WebSocket closed code = %ld ,reason = %@",code,reason);
    
    self.connectStatus = ConnectStatus_UnConnected;
    
    
    if (self.autoReconnect) {
        __weak __typeof(self) weakself = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, _connectTimerInterval), dispatch_get_main_queue(), ^{
            [weakself startConnectTimer:weakself.connectTimerInterval];
        });
    }
    
//    if (self.reconnectionCount >= 0 && self.reconnectionCount <= HeartBeatMaxLostCount && self.autoReconnect) {
//        NSTimeInterval time = pow(2, self.reconnectionCount);
//        
//        if (!self.reconnectTimer) {
//            
//            self.reconnectTimer = [NSTimer scheduledTimerWithTimeInterval:time
//                                                                   target:self
//                                                                 selector:@selector(reconnect:)
//                                                                 userInfo:HeartBeatIdentifier
//                                                                  repeats:NO];
//            [[NSRunLoop mainRunLoop] addTimer:self.reconnectTimer forMode:NSRunLoopCommonModes];
//        }
//        self.reconnectionCount++;
//        
//    } else {
//        [self.reconnectTimer invalidate];
//        self.reconnectTimer = nil;
//        self.reconnectionCount = 0;
//    }
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
