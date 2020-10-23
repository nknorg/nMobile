//
//  NKNPushService.h
//  Runner
//
//  Created by  Rebloom on 2020/9/21.
//  Copyright © 2020 The Chromium Authors. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NWHub.h"

NS_ASSUME_NONNULL_BEGIN

@interface NKNPushService : NSObject <NWHubDelegate>
{
    NWHub *_hub;
    dispatch_queue_t _serial;
    
    NWIdentityRef _identity;
    NWCertificateRef _certificate;
}

+ (NKNPushService *)sharedService;

- (void)pushContent:(NSString *)pushContent token:(NSString *)pushToken;

- (void)connectAPNS;

@end

NS_ASSUME_NONNULL_END
