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
    
    // [self testWebSocketServer];
}

- (IBAction)acceptBtnDidClick:(NSButton *)sender {
    
    SKSocketServerManager *serverSocket = [SKSocketServerManager sharedServerManager];
    serverSocket.port = self.portTextField.stringValue.length == 0 ?  8888 : [self.portTextField.stringValue intValue];
    serverSocket.listenAddress =self.ipTextField.stringValue.length == 0 ?  @"10.22.64.148" : self.ipTextField.stringValue;
    // 开始监听
    [[SKSocketServerManager sharedServerManager] startAccept];
}

//  测试 websocket server
- (void)testWebSocketServer {

    SKWebSocketServerManager *serverSocket = [SKWebSocketServerManager sharedServerManager];
    serverSocket.port = self.portTextField.stringValue.length == 0 ?  8888 : [self.portTextField.stringValue intValue];
    serverSocket.listenAddress =self.ipTextField.stringValue.length == 0 ?  @"10.22.64.148" : self.ipTextField.stringValue;
    [serverSocket startAccept];

}



- (void)webSocketServer:(SKWebSocketServerManager *)server didAcceptNewConnection:(GCDAsyncSocket *)newConnection {

    NSLog(@"didAcceptNewConnection");
}

- (void)webSocketServer:(SKWebSocketServerManager *)server clientDidDisconnect:(GCDAsyncSocket *)connection withError:(NSError *)err {
    NSLog(@"clientDidDisconnect ERROR = %@",err);

}

- (void)webSocketServer:(SKWebSocketServerManager *)server didReceiveData:(NSData *)data fromConnection:(GCDAsyncSocket *)connection {
    
    NSLog(@"didReceiveData");

    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        // 去除'\n'
        str  = [str stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        NSLog(@"server didReadData = %@",str );
    });

}

- (void)webSocketServer:(SKWebSocketServerManager *)server couldNotParseRawData:(NSData *)data fromConnection:(GCDAsyncSocket *)connection withError:(NSError *)err {
    
    NSLog(@"couldNotParseRawData");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        // 去除'\n'
        str  = [str stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        NSLog(@"server couldNotParseRawData = %@",str );
    });
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
