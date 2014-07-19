/**
 Copyright (c) 2014-present, Facebook, Inc.
 All rights reserved.
 
 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

@class FBTweakClient;

@protocol FBTweakClientDelegate<NSObject>
@optional
- (void)clientConnectionAttemptSucceeded:(FBTweakClient *)client;
- (void)clientConnectionAttemptFailed:(FBTweakClient *)client;
- (void)clientConnectionTerminated:(FBTweakClient *)client;
- (void)client:(FBTweakClient *)client receivedMessage:(NSDictionary *)message;
@end

@interface FBTweakClient : NSObject<NSNetServiceDelegate>
@property (nonatomic, weak) id<FBTweakClientDelegate> delegate;

- (id)initWithNativeSocketHandle:(CFSocketNativeHandle)nativeSocketHandle;
- (id)initWithNetService:(NSNetService *)netService;

- (BOOL)connect;
- (void)close;
- (void)sendNetworkPacket:(NSDictionary *)packet;
@end