//
//  SKSocketHeader.h
//  Client_Socket
//
//  Created by KUN on 2017/8/30.
//  Copyright © 2017年 lemon. All rights reserved.
//
//

#if DEBUG
static NSString * HOST = @"10.22.64.148";
static const int PORT = 8888;
#else
static NSString * HOST = @"10.22.64.148";
static const int PORT = 7070;
#endif

static NSTimeInterval TimeOut = -1;        // 超时时间, 超时会关闭 socket
static NSTimeInterval HeartBeatRate = 5;   // 💖心跳频率
static NSInteger  HeartBeatMaxLostCount = 3;   // 最大心跳丢失数
static NSString  *HeartBeatIdentifier = @"heart";   // 心跳标识

static NSTimeInterval kConnectMaxCount = 5 ; // 最大断开重连次数
static NSTimeInterval kConnectTimerInterval = 3 ; //重连时间间隔 单位秒s


typedef enum : NSUInteger {
    
    ConnectStatus_UnConnected  = 0,  //未连接
    ConnectStatus_Connected    = 1,  //已连接
    ConnectStatus_Connecting  = 2,  //连接中
    
} ConnectStatus;

typedef enum : NSUInteger {
    
    WebSocketOfflineStyle_NetWork  = 0,  //网络原因中断
    WebSocketOfflineStyle_User    = 1,  //用户主动中断
    
} WebSocketOfflineStyle;


#ifdef DEBUG
# define DDLog(format, ...) NSLog((@"[函数名:%s]" "[行号:%d]" format), __FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
# define DDLog(...);
#endif

