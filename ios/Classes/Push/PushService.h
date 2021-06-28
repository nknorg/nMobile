//
//  PushService.h
//  Runner
//
//  Created by  ZhiGuoJiang on 2020/9/21.
//  Copyright © 2020 The Chromium Authors. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NWHub.h"

NS_ASSUME_NONNULL_BEGIN

@interface PushService : NSObject <NWHubDelegate>
{
    NWHub *_hub;
    dispatch_queue_t _serial;
    
    NWIdentityRef _identity;
    NWCertificateRef _certificate;
}

@property (nonatomic, strong) NSURLSession * session;
@property (nonatomic, strong) NSURLSessionDataTask * dataTask;

+ (PushService *)sharedService;

- (void)pushContent:(NSString *)pushContent token:(NSString *)pushToken;

- (void)connectAPNS;

- (void)disConnectAPNS;

@end

NS_ASSUME_NONNULL_END
