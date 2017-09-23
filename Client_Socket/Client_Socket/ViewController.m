//
//  ViewController.m
//  Client_Socket
//
//  Created by KUN on 2017/8/22.
//  Copyright © 2017年 lemon. All rights reserved.
//

#import "ViewController.h"
#import "SKSocketManager.h"
#import "SKWebSocketManager.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextField *inputTextF;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [SKWebSocketManager sharedInstance].socketHost = @"ws://101.132.98.228:8282";
    [[SKWebSocketManager sharedInstance] addDelegate:self delegateQueue:dispatch_get_main_queue()];
    [[SKWebSocketManager sharedInstance] connect];

}
// 发送
- (IBAction)sendAct:(UIButton *)sender {

    [[SKWebSocketManager sharedInstance] sendData:self.inputTextF.text];

}

#pragma mark -- SKWebSocketManagerDelegate

/**
 连接成功
 */
- (void)webSocketDidConnectToSocketHost:(NSString *)host {

    [[SKWebSocketManager sharedInstance] sendData:@"test"];
}

/**
 连接失败
 */
- (void)webSocketConnectFailueWithError:(NSError *)error {
    
}

/**
 socket 自动重连
 */
- (void)webSocketdidReconnectCount:(NSInteger)reconectCount exceedMaxRecordCount:(BOOL)exceedMaxRecordCount{
    
    NSString *toasst ;
    if (exceedMaxRecordCount) {
        toasst = [NSString stringWithFormat:@"呜呜呜...网络真的断了！"];
        
    } else {
        toasst = [NSString stringWithFormat:@"第%ld次重新连接服务器...",reconectCount];
    }
    
    NSLog(@"%@",toasst);
}

/**
 socket 断开连接
 */
- (void)webSocketdidCloseWithCode:(NSInteger)code reason:(WebSocketOfflineStyle)offlineStyle {
    
    NSLog(@"与服务器断开连接");
}

- (void)webSocketdidReceiveMessage:(id)message {
    NSLog(@"Received \"%@\"", message);
    
    NSString *receivedStr = message;
    NSData *data = [receivedStr dataUsingEncoding:NSUTF8StringEncoding];
    id mes = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
    
    if (![mes isKindOfClass:[NSDictionary class]]) {
        return;
    }
}


@end
