//
//  ViewController.m
//  Server_Socket
//
//  Created by KUN on 2017/8/18.
//  Copyright © 2017年 lemon. All rights reserved.
//

#import "ViewController.h"
#import "SKSocketServerManager.h"
#import "SKWebSocketServerManager.h"


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
    
    SKSocketServerManager *serverSocket = [SKSocketServerManager sharedServerManager];
//    SKWebSocketServerManager *serverSocket = [SKWebSocketServerManager sharedServerManager];

    serverSocket.port = self.portTextField.stringValue.length == 0 ?  8888 : [self.portTextField.stringValue intValue];
    serverSocket.listenAddress =self.ipTextField.stringValue.length == 0 ?  @"10.22.64.148" : self.ipTextField.stringValue;
    // 开始监听
    [[SKSocketServerManager sharedServerManager] startAccept];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
}

- (void)awakeFromNib {
   	[self.logView setEnabledTextCheckingTypes:0];
    [self.logView setAutomaticSpellingCorrectionEnabled:NO];
}




- (void)scrollToBottom
{
    NSScrollView *scrollView = [self.logView enclosingScrollView];
    NSPoint newScrollOrigin;
    
    if ([[scrollView documentView] isFlipped])
        newScrollOrigin = NSMakePoint(0.0F, NSMaxY([[scrollView documentView] frame]));
    else
        newScrollOrigin = NSMakePoint(0.0F, 0.0F);
    
    [[scrollView documentView] scrollPoint:newScrollOrigin];
}

- (void)logError:(NSString *)msg
{
    NSString *paragraph = [NSString stringWithFormat:@"%@\n", msg];
    
    NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithCapacity:1];
    [attributes setObject:[NSColor redColor] forKey:NSForegroundColorAttributeName];
    
    NSAttributedString *as = [[NSAttributedString alloc] initWithString:paragraph attributes:attributes];
    
    [[self.logView textStorage] appendAttributedString:as];
    [self scrollToBottom];
}

- (void)logInfo:(NSString *)msg
{
    NSString *paragraph = [NSString stringWithFormat:@"%@\n", msg];
    
    NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithCapacity:1];
    [attributes setObject:[NSColor purpleColor] forKey:NSForegroundColorAttributeName];
    
    NSAttributedString *as = [[NSAttributedString alloc] initWithString:paragraph attributes:attributes];
    
    [[self.logView textStorage] appendAttributedString:as];
    [self scrollToBottom];
}

- (void)logMessage:(NSString *)msg
{
    NSString *paragraph = [NSString stringWithFormat:@"%@\n", msg];
    
    NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithCapacity:1];
    [attributes setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
    
    NSAttributedString *as = [[NSAttributedString alloc] initWithString:paragraph attributes:attributes];
    
    [[self.logView textStorage] appendAttributedString:as];
    [self scrollToBottom];
}
@end
