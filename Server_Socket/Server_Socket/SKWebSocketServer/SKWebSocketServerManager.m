//
//  SKWebSocketServerManager.m
//  Server_Socket
//
//  Created by KUN on 2017/8/22.
//  Copyright © 2017年 lemon. All rights reserved.
//

#import "SKWebSocketServerManager.h"
#import "SKSocketServerConnection.h"
#import "GCDAsyncSocket.h"
#import <CommonCrypto/CommonDigest.h>


@interface SKWebSocketServerManager () <GCDAsyncSocketDelegate, SKSocketServerConnectionDelegate>

@property (nonatomic, strong) GCDAsyncSocket *webSocket;

@property (nonatomic, strong) dispatch_queue_t socketQueue;

@property (nonatomic, strong, readwrite) NSMutableArray *connections;

@end

@interface NSString (SKWebSocketServerManager)
- (id)sk_base64;
- (id)webSocketFrameData;
@end
@interface NSData (SKWebSocketServerManager)
- (id)webSocketFrameData;
@end

@implementation SKWebSocketServerManager

+ (SKWebSocketServerManager *)sharedServerManager {
    
    static SKWebSocketServerManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[SKWebSocketServerManager alloc] init];
    });
    return manager;
}

- (instancetype)init
{
    if (self = [super init]) {
        
        _socketQueue = dispatch_queue_create("webSocketQueue", NULL);
        _webSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_socketQueue];
        
        _connections = [[NSMutableArray alloc] initWithCapacity:1];
        
    }
    return self;
}

- (void)startAccept {
    
    NSError *error = nil;
    [_webSocket acceptOnInterface:self.listenAddress port:self.port error:&error];
//    [_webSocket acceptOnPort:_port error:&error];
    if (error) {
        NSLog(@"监听失败:%@",error);
        
    } else {
        NSLog(@"监听成功:%@",error);
        NSLog(@"websocket server started on port %hu", [_webSocket localPort]);
        
    }
}

- (void)send:(id)object {

}


- (NSString *)handshakeResponseForData:(NSData *)data {
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray *strings = [string componentsSeparatedByString:@"\r\n"];
    
    if (strings.count && [strings[0] isEqualToString:@"GET / HTTP/1.1"])
        for (NSString *line in strings) {
            NSArray *parts = [line componentsSeparatedByString:@":"];
            if (parts.count == 2 && [parts[0] isEqualToString:@"Sec-WebSocket-Key"]) {
                id key = [parts[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                id secWebSocketAccept = [[key stringByAppendingString:@"258EAFA5-E914-47DA-95CA-C5AB0DC85B11"] sk_base64];
                return [NSString stringWithFormat:
                        @"HTTP/1.1 101 Web Socket Protocol Handshake\r\n"
                        "Upgrade: websocket\r\n"
                        "Connection: Upgrade\r\n"
                        "Sec-WebSocket-Accept: %@\r\n\r\n",
                        secWebSocketAccept];
            }
        }
    
    @throw @"Invalid handshake from client";
}

#pragma mark -- GCDAsyncSocketDelegate



- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket;{
    DDLog(@"didAcceptNewSocket");
    
    @synchronized (_connections) {
        
        [_connections addObject:newSocket];

        [newSocket readDataWithTimeout:-1 tag:1];
    }
    
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    DDLog(@"host = %@,port = %d",host,port);
    
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToUrl:(NSURL *)url {
    DDLog(@"didConnectToUrl = %@",url);
}


- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    
    DDLog(@"didReadData tag = %ld",tag);
//    [sock readDataWithTimeout:-1 tag:tag];
    
    @try {
        const unsigned char *bytes = data.bytes;
        switch (tag) {
            case 1: {
                NSString *handshake = [self handshakeResponseForData:data];
                [sock writeData:[handshake dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:2];
                break;
            }
            case 4: {
                uint64_t const N = bytes[1] & 0x7f;
                char const opcode = bytes[0] & 0x0f;
                
                // TODO support fragmented frames (first bit unset in control frame)
                if (!bytes[0] & 0x80)
                    @throw @"Can't decode fragmented frames!";
                
                switch (opcode) {
                    case 1:  //  text frame
                    case 8:  // close frame http://tools.ietf.org/html/rfc6455#section-5.5.1
                    case 9:  //  ping frame http://tools.ietf.org/html/rfc6455#section-5.5.2
                        if (!bytes[1] & 0x80)
                            @throw @"Can only handle websocket frames with masks!";
                        if (N >= 126)
                            [sock readDataToLength:N == 126 ? 2 : 8 withTimeout:-1 buffer:nil bufferOffset:0 tag:16 + opcode];
                        else
                            [sock readDataToLength:N + 4 withTimeout:-1 buffer:nil bufferOffset:0 tag:32 + opcode];
                        break;
                    default:
                        @throw @"Cannot handle this websocket frame format!";
                }
                break;
            }
            case 0x11: // figure out payload length
            case 0x18:
            case 0x19: {
                uint64_t N;
                if (data.length == 2) {
                    uint16_t *p = (uint16_t *)bytes;
                    N = ntohs(*p) + 4;
                } else {
                    uint64_t *p = (uint64_t *)bytes;
                    N = ntohll(*p) + 4;
                }
                [sock readDataToLength:N withTimeout:-1 buffer:nil bufferOffset:0 tag:16 + tag];
                break;
            }
            case 0x21: // read complete payload
            case 0x28:
            case 0x29: {
                NSMutableData *unmaskedData = [NSMutableData dataWithCapacity:data.length - 4];
                for (int x = 4; x < data.length; ++x) {
                    char c = bytes[x] ^ bytes[x%4];
                    [unmaskedData appendBytes:&c length:1];
                }
                
                switch (tag & 0xf) {
                    case 1: {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [_delegate webSocketServer:self didReceiveData:unmaskedData fromConnection:sock];
                        });
                        break;
                    }
                    case 8: { // CLOSE
                        char rsp[4] = {0x88, 2, bytes[1], bytes[0]}; // final two bytes are network-byte-order statusCode that we echo back
                        [sock writeData:[NSData dataWithBytes:rsp length:4] withTimeout:-1 tag:-1];
                        break;
                    }
                    case 9: { // PING
                        NSMutableData *ping = [unmaskedData webSocketFrameData];// FIXME inefficient (but meh)
                        ((char *)ping.mutableBytes)[0] = 0x8a;
                        [sock writeData:ping withTimeout:-1 tag:-1];
                        break;
                    }
                }
                
                // configure the connection to wait for the next frame
                [sock readDataToLength:2 withTimeout:-1 buffer:nil bufferOffset:0 tag:4];
                break;
            }
        }
    }
    @catch (id msg) {
        id err = [NSError errorWithDomain:@"com.lemon.webSocketServer" code:1 userInfo:@{NSLocalizedDescriptionKey: msg}];
        dispatch_sync(dispatch_get_main_queue(), ^{
            if (_delegate) {
                [_delegate webSocketServer:self couldNotParseRawData:data fromConnection:sock withError:err];
            }
        });
        [sock disconnect]; //FIXME some cases do not require disconnect
    }
    
}

- (void)socket:(GCDAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
    
    DDLog(@"partialLength = %ld ,tag = %ld",partialLength ,tag);
    
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    
    DDLog(@"didWriteDataWithTag tag = %ld" ,tag);
    
    if (tag == 2) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if (_delegate) {
                [_delegate webSocketServer:self didAcceptNewConnection:sock];
            }
        }];
        [sock readDataToLength:2 withTimeout:-1 buffer:nil bufferOffset:0 tag:4];
    }

}


- (void)socketDidCloseReadStream:(GCDAsyncSocket *)sock {
    DDLog(@"socketDidCloseReadStream");
    
}


- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)err {
    DDLog(@"socketDidDisconnect");
    [_connections removeObjectIdenticalTo:sock];
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        if (_delegate) {
            [_delegate webSocketServer:self clientDidDisconnect:sock withError:err];
        }
    }];
}

- (void)socketDidSecure:(GCDAsyncSocket *)sock {
    DDLog(@"socketDidSecure");
    
}


#pragma mark -- SKServerSocketConnectionDelegate

- (void)didDisConnect:(SKSocketServerConnection *)con withError:(NSError *)error {
    
    @synchronized(_connections) {
        [_connections removeObject:con];
    }
}

@end

@implementation NSString (SKWebSocketServerManager)

- (id)sk_base64 {
    NSMutableData* data = (id) [self dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char input[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(data.bytes, (unsigned)data.length, input);
    
    static const char map[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    
    data = [NSMutableData dataWithLength:28];
    uint8_t* out = (uint8_t*) data.mutableBytes;
    
    for (int i = 0; i < 20;) {
        int v  = 0;
        for (const int N = i + 3; i < N; i++) {
            v <<= 8;
            v |= 0xFF & input[i];
        }
        *out++ = map[v >> 18 & 0x3F];
        *out++ = map[v >> 12 & 0x3F];
        *out++ = map[v >> 6 & 0x3F];
        *out++ = map[v >> 0 & 0x3F];
    }
    out[-2] = map[(input[19] & 0x0F) << 2];
    out[-1] = '=';
    return [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
}

- (id)webSocketFrameData {
    return [[self dataUsingEncoding:NSUTF8StringEncoding] webSocketFrameData];
}
@end


@implementation NSData (SKWebSocketServerManager)

- (id)webSocketFrameData {
    NSMutableData *data = [NSMutableData dataWithLength:10];
    char *header = data.mutableBytes;
    header[0] = 0x81;
    
    if (self.length > 65535) {
        header[1] = 127;
        header[2] = (self.length >> 56) & 255;
        header[3] = (self.length >> 48) & 255;
        header[4] = (self.length >> 40) & 255;
        header[5] = (self.length >> 32) & 255;
        header[6] = (self.length >> 24) & 255;
        header[7] = (self.length >> 16) & 255;
        header[8] = (self.length >>  8) & 255;
        header[9] = self.length & 255;
    } else if (self.length > 125) {
        header[1] = 126;
        header[2] = (self.length >> 8) & 255;
        header[3] = self.length & 255;
        data.length = 4;
    } else {
        header[1] = self.length;
        data.length = 2;
    }
    
    [data appendData:self];
    
    return data;
}

@end
