//
//  ViewController.m
//  Server_Socket
//
//  Created by KUN on 2017/8/18.
//  Copyright © 2017年 lemon. All rights reserved.
//

#import "ViewController.h"
#import "SKServerSocketManager.h"

@interface ViewController ()

@property (weak) IBOutlet NSTextField *ipTextField;
@property (weak) IBOutlet NSTextField *portTextField;

@property (unsafe_unretained) IBOutlet NSTextView *logView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)acceptBtnDidClick:(NSButton *)sender {
    
    SKServerSocketManager *serverSocket = [SKServerSocketManager sharedServerManager];
    serverSocket.port = self.portTextField.stringValue.length ?  8888 : [self.portTextField.stringValue intValue];
    serverSocket.listenAddress =self.ipTextField.stringValue.length ?  @"10.22.64.79" : self.ipTextField.stringValue;
    // 开始监听
    [[SKServerSocketManager sharedServerManager] startAccept];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
}

- (void)awakeFromNib {
   	[self.logView setEnabledTextCheckingTypes:0];
    [self.logView setAutomaticSpellingCorrectionEnabled:NO];
}

@end
