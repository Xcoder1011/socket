//
//  ViewController.m
//  Client_Socket
//
//  Created by KUN on 2017/8/22.
//  Copyright © 2017年 lemon. All rights reserved.
//

#import "ViewController.h"
#import "SKSocketManager.h"


@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextField *inputTextF;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[SKSocketManager sharedInstance] connect];
}
// 发送
- (IBAction)sendAct:(UIButton *)sender {

    [[SKSocketManager sharedInstance] sendData:self.inputTextF.text];
}

@end
