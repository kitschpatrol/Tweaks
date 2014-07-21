/**
 Copyright (c) 2014-present, Facebook, Inc.
 All rights reserved.
 
 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */


#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <CFNetwork/CFSocketStream.h>

#import "FBTweakEnabled.h"
#import "FBTweakServer.h"
#import "FBTweakStore.h"
#import "FBTweakCategory.h"
#import "FBTweakCollection.h"
#import "FBTweak.h"

#if FB_TWEAK_SERVER_ENABLED

// Create a server to listen for incoming connections on startup (without any client code)
@interface FBTweakRuntime : NSObject
@end

@implementation FBTweakRuntime

static FBTweakServer *server = nil;

+ (void)load {
  server = [[FBTweakServer alloc] init];
  [server start];
}

@end

#endif

@interface FBTweakServer() {
  CFSocketRef _listeningSocket;
}

@property (nonatomic, assign) NSInteger port;
@property (nonatomic, strong) NSNetService *netService;
@property (nonatomic, strong) NSMutableArray *clients;

- (BOOL)createServer;
- (void)terminateServer;

- (BOOL)publishService;
- (void)unpublishService;
@end

@implementation FBTweakServer

- (id)init {
  if(self = [super init]) {
    _clients = [[NSMutableArray alloc] init];
  }
  
  return self;
}

- (void)dealloc {
  [self stop];
}

- (BOOL)start {
  if(![self createServer]) {
    return NO;
  }
  
  if(![self publishService]) {
    [self terminateServer];
    return NO;
  }
  
  return YES;
}

- (void)stop {
  [self terminateServer];
  [self unpublishService];
}

- (void)refreshData:(FBTweakClient *)client {
  FBTweakStore *tweakStore = [FBTweakStore sharedInstance];
  
  NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
  NSMutableArray *categoryArray = [NSMutableArray array];
  
  for(FBTweakCategory *tweakCategory in tweakStore.tweakCategories) {
    NSMutableDictionary *categoryDictionary = [NSMutableDictionary dictionary];
    categoryDictionary[@"name"] = tweakCategory.name;
    
    NSMutableArray *collectionArray = [NSMutableArray array];
    
    for(FBTweakCollection *tweakCollection in tweakCategory.tweakCollections) {
      NSMutableDictionary *collectionDictionary = [NSMutableDictionary dictionary];
      collectionDictionary[@"name"] = tweakCollection.name;
      
      NSMutableArray *tweakArray = [NSMutableArray array];
      
      for(FBTweak *tweak in tweakCollection.tweaks) {
        NSMutableDictionary *tweakDictionary = [NSMutableDictionary dictionary];
        tweakDictionary[@"name"] = tweak.name;
        tweakDictionary[@"identifier"] = tweak.identifier;
        
        NSString *tweakType = @"None";
        
        FBTweakValue value = tweak.currentValue ? tweak.currentValue : tweak.defaultValue;
        FBTweakValue minimumValue = tweak.minimumValue;
        FBTweakValue maximumValue = tweak.maximumValue;
        FBTweakValue stepValue = tweak.stepValue;
        FBTweakValue precisionValue = tweak.precisionValue;
        
        
        
        if([value isKindOfClass:[NSString class]]) {
          tweakType = @"String";
        }
        else if([value isKindOfClass:[NSNumber class]]) {
          // In the 64-bit runtime, BOOL is a real boolean.
          // NSNumber doesn't always agree; compare both.
          if (strcmp([value objCType], @encode(char)) == 0 ||
              strcmp([value objCType], @encode(_Bool)) == 0) {
            tweakType = @"Boolean";
          }
          else if(strcmp([value objCType], @encode(NSInteger)) == 0 ||
                  strcmp([value objCType], @encode(NSUInteger)) == 0) {
            tweakType = @"Integer";
          }
          else {
            tweakType = @"Real";
          }
        }
        else if([tweak isAction]) {
          tweakType = @"Action";
          value = nil;
        }
        
        tweakDictionary[@"type"] = tweakType;
        
        if(value) {
          tweakDictionary[@"value"] = value;
        }
        
        if(minimumValue) {
          tweakDictionary[@"minimumValue"] = minimumValue;
        }
        
        if(maximumValue) {
          tweakDictionary[@"maximumValue"] = maximumValue;
        }
        
        if(stepValue) {
          tweakDictionary[@"stepValue"] = stepValue;
        }
        
        if(precisionValue) {
          tweakDictionary[@"precisionValue"] = precisionValue;
        }
        
        [tweakArray addObject:tweakDictionary];
      }
      
      collectionDictionary[@"tweaks"] = tweakArray;
      [collectionArray addObject:collectionDictionary];
    }
    
    categoryDictionary[@"collections"] = collectionArray;
    [categoryArray addObject:categoryDictionary];
  }
  
  dictionary[@"categories"] = categoryArray;
  
  [client sendNetworkPacket:dictionary];
}

#pragma mark Callbacks

- (void)handleNewNativeSocket:(CFSocketNativeHandle)nativeSocketHandle {
  FBTweakClient *client = [[FBTweakClient alloc] initWithNativeSocketHandle:nativeSocketHandle];
  
  if(client == nil) {
    close(nativeSocketHandle);
    return;
  }
  
  if(![client connect]) {
    [client close];
    client = nil;
    return;
  }
  
  client.delegate = self;
  [self.clients addObject:client];
}


static void serverAcceptCallback(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
  FBTweakServer *server = (__bridge FBTweakServer*)info;
  
  if(type != kCFSocketAcceptCallBack) {
    return;
  }
  
  CFSocketNativeHandle nativeSocketHandle = *(CFSocketNativeHandle *)data;
  
  [server handleNewNativeSocket:nativeSocketHandle];
}


#pragma mark Sockets and streams

- (BOOL)createServer {
  CFSocketContext socketCtxt = {0, (__bridge void *)(self), NULL, NULL, NULL};
  
  _listeningSocket = CFSocketCreate(
                                    kCFAllocatorDefault,
                                    PF_INET,        // The protocol family for the socket
                                    SOCK_STREAM,    // The socket type to create
                                    IPPROTO_TCP,    // The protocol for the socket. TCP vs UDP.
                                    kCFSocketAcceptCallBack,  // New connections will be automatically accepted and the callback is called with the data argument being a pointer to a CFSocketNativeHandle of the child socket.
                                    (CFSocketCallBack)&serverAcceptCallback,
                                    &socketCtxt );
  
  if(_listeningSocket == NULL) {
    return NO;
  }
  
  int existingValue = 1;
  
  setsockopt(CFSocketGetNative(_listeningSocket),
             SOL_SOCKET, SO_REUSEADDR, (void *)&existingValue,
             sizeof(existingValue));
  
  struct sockaddr_in socketAddress;
  memset(&socketAddress, 0, sizeof(socketAddress));
  socketAddress.sin_len = sizeof(socketAddress);
  socketAddress.sin_family = AF_INET;   // Address family (IPv4 vs IPv6)
  socketAddress.sin_port = 0;           // Actual port will get assigned automatically by kernel
  socketAddress.sin_addr.s_addr = htonl(INADDR_ANY);    // We must use "network byte order" format (big-endian) for the value here
  
  NSData *socketAddressData =
  [NSData dataWithBytes:&socketAddress length:sizeof(socketAddress)];
  
  if(CFSocketSetAddress(_listeningSocket, (__bridge CFDataRef)socketAddressData) != kCFSocketSuccess ) {
    if(_listeningSocket) {
      CFRelease(_listeningSocket);
      _listeningSocket = NULL;
    }
    
    return NO;
  }
  
  NSData *socketAddressActualData = (__bridge_transfer NSData *)CFSocketCopyAddress(_listeningSocket);
  
  struct sockaddr_in socketAddressActual;
  memcpy(&socketAddressActual, [socketAddressActualData bytes], [socketAddressActualData length]);
  
  self.port = ntohs(socketAddressActual.sin_port);
  
  CFRunLoopRef currentRunLoop = CFRunLoopGetCurrent();
  CFRunLoopSourceRef runLoopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _listeningSocket, 0);
  CFRunLoopAddSource(currentRunLoop, runLoopSource, kCFRunLoopCommonModes);
  CFRelease(runLoopSource);
  
  return YES;
}


- (void)terminateServer {
  if(_listeningSocket) {
    CFSocketInvalidate(_listeningSocket);
		CFRelease(_listeningSocket);
		_listeningSocket = NULL;
  }
}


#pragma mark - Bonjour

- (BOOL)publishService {
  NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:(__bridge NSString *)kCFBundleVersionKey];
  NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
  NSString *serviceName = [NSString stringWithFormat:@"%@_%@", appName, version];
  
 	self.netService = [[NSNetService alloc] initWithDomain:@""
                                                    type:@"_tweaks._tcp."
                                                    name:serviceName
                                                    port:self.port];
  
	[self.netService scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
  [self.netService setDelegate:self];
	[self.netService publish];
  
  return YES;
}

- (void)unpublishService {
  if(self.netService) {
    [self.netService stop];
    [self.netService removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    self.netService = nil;
  }
}

#pragma mark - NSNetServiceDelegate

- (void)netService:(NSNetService*)sender didNotPublish:(NSDictionary*)errorDict {
  if(sender != self.netService ) {
    return;
  }
  
  [self terminateServer];
  [self unpublishService];
}

# pragma mark - FBTweakClientDelegate

- (void)clientConnectionAttemptFailed:(FBTweakClient *)client {
  [self.clients removeObject:client];
}

- (void)clientConnectionTerminated:(FBTweakClient *)client {
  [self.clients removeObject:client];
}

- (void)client:(FBTweakClient *)client receivedMessage:(NSDictionary *)message {
  NSString *messageType = message[@"type"];
  
  if([messageType isEqualToString:@"refresh"]) {
    [self refreshData:client];
  }
  else if([messageType isEqualToString:@"action"]) {
    FBTweakStore *tweakStore = [FBTweakStore sharedInstance];
    
    NSDictionary *tweakDictionary = message[@"tweak"];
    NSString *categoryName = tweakDictionary[@"category"];
    NSString *collectionName = tweakDictionary[@"collection"];
    NSString *tweakIdentifier = tweakDictionary[@"identifier"];
    
    // Refactor this search method!
    for(FBTweakCategory *category in tweakStore.tweakCategories) {
      if([category.name isEqualToString:categoryName]) {
        for(FBTweakCollection *collection in category.tweakCollections) {
          if([collection.name isEqualToString:collectionName]) {
            for(FBTweak *tweak in collection.tweaks) {
              if([tweak.identifier isEqualToString:tweakIdentifier]) {
                dispatch_block_t block = tweak.defaultValue;
                
                if(block) {
                  block();
                }
                break;
              }
            }
            
            break;
          }
        }
        
        break;
      }
    }
  }
  else if([messageType isEqualToString:@"valueChanged"]) {
    FBTweakStore *tweakStore = [FBTweakStore sharedInstance];
    
    NSDictionary *tweakDictionary = message[@"tweak"];
    NSString *categoryName = tweakDictionary[@"category"];
    NSString *collectionName = tweakDictionary[@"collection"];
    NSString *tweakIdentifier = tweakDictionary[@"identifier"];
    
    // Refactor this search method!
    for(FBTweakCategory *category in tweakStore.tweakCategories) {
      if([category.name isEqualToString:categoryName]) {
        for(FBTweakCollection *collection in category.tweakCollections) {
          if([collection.name isEqualToString:collectionName]) {
            for(FBTweak *tweak in collection.tweaks) {
              if([tweak.identifier isEqualToString:tweakIdentifier]) {
                tweak.currentValue = tweakDictionary[@"value"];
                break;
              }
            }
            
            break;
          }
        }
        
        break;
      }
    }
  }
}

@end
