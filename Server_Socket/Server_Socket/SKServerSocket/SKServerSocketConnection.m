//
//  SKServerSocketConnection.m
//  Server_Socket
//
//  Created by KUN on 2017/8/21.
//  Copyright © 2017年 lemon. All rights reserved.
//

#import "SKServerSocketConnection.h"
#import "GCDAsyncSocket.h"

@interface SKServerSocketConnection ()

@property (nonatomic, strong) GCDAsyncSocket *socket;

@end

@implementation SKServerSocketConnection

- (instancetype)init {

    if (self = [super init]) {
        //
    }
    return self;

}

@end
