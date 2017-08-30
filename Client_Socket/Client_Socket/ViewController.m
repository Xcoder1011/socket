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
    
    [SKWebSocketManager sharedInstance].socketHost = @"ws://139.196.84.33:8282";
//    [SKWebSocketManager sharedInstance].socketHost = @"ws://10.22.64.148:8888";
    [[SKWebSocketManager sharedInstance] connect];

}
// 发送
- (IBAction)sendAct:(UIButton *)sender {

//    [[SKSocketManager sharedInstance] sendData:self.inputTextF.text];
    
    NSError *error;
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@{@"id":@"wushangkun",@"content":self.inputTextF.text} options:NSJSONWritingPrettyPrinted error:&error];
    
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    [[SKWebSocketManager sharedInstance] sendData:jsonString];
}

@end
