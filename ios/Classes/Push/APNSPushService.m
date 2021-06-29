//
//  APNSPushService.m
//  Runner
//
//  Created by  ZhiGuoJiang on 2020/9/21.
//  Copyright © 2020 The Chromium Authors. All rights reserved.
//

#import "APNSPushService.h"

#import "NWSecTools.h"

#import <Nkn/Nkn.h>

#define Push_Developer   "gateway.sandbox.push.apple.com"
#define Push_Production  "gateway.push.apple.com"

// If you want to add APNS, locate your own p12 or .cer file here
#define APNSPushFileName            @"filename"
#define APNSPushPassword            @"password"

@implementation APNSPushService

static APNSPushService * sharedService = nil;
+ (APNSPushService *)sharedService{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedService = [[self alloc] init];
    });
    return sharedService;
}

- (void)connectAPNS{
    if(_serial == nil){
        _serial = dispatch_queue_create("APNSPushService", DISPATCH_QUEUE_CONCURRENT);
    }
    // If you want to add APNS, locate your own p12 or .cer file here
    NSURL *url = [NSBundle.mainBundle URLForResource:APNSPushFileName withExtension:nil];
    NSData *pkcs12 = [NSData dataWithContentsOfURL:url];
    NSError *error = nil;
    
    // Change your own p12 password Here
    NSArray *ids = [NWSecTools identitiesWithPKCS12Data:pkcs12 password:APNSPushPassword error:&error];
    if (!ids) {
        NSLog(@"Unable to read p12 file: %@", error.localizedDescription);
        return;
    }
    for (NWIdentityRef identity in ids) {
        NSError *error = nil;
        NWCertificateRef certificate = [NWSecTools certificateWithIdentity:identity error:&error];
        if (!certificate) {
            NSLog(@"Unable to import p12 file: %@", error.localizedDescription);
            return;
        }
        
        _identity = identity;
        _certificate = certificate;
    }
    
    NSLog(@"Connecting..");
    __block NWHub * blockHub = _hub;
    __block NWCertificateRef blockCertificate = _certificate;
    __block NWIdentityRef blockIdentity = _identity;
    dispatch_async(_serial, ^{
        NSError *error = nil;
        NWEnvironment preferredEnvironment = [self preferredEnvironmentForCertificate:blockCertificate];
        NWHub *hub = [NWHub connectWithDelegate:self identity:blockIdentity environment:NWEnvironmentProduction error:&error];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (hub) {
                NSString *summary = [NWSecTools summaryWithCertificate:blockCertificate];
                NSLog(@"Connected to APN: %@ (%@)", summary, descriptionForEnvironent(preferredEnvironment));
                blockHub = hub;
            }
            else
            {
                NSLog(@"Unable to connect: %@", error.localizedDescription);
            }
        });
    });
}

- (void)disConnectAPNS{
    if (_hub){
        [_hub disconnect];
    }
}

-(NWEnvironment)preferredEnvironmentForCertificate:(NWCertificateRef)certificate
{
    NWEnvironmentOptions environmentOptions = [NWSecTools environmentOptionsForCertificate:certificate];
    
    return (environmentOptions & NWEnvironmentOptionSandbox) ? NWEnvironmentSandbox : NWEnvironmentProduction;
}


- (void)pushContent:(NSString *)pushPayload token:(NSString *)pushToken{
    __block NSString * blockPayload = pushPayload;
    __block NSString * blockToken = pushToken;
    __block NWHub * blockHub = _hub;
    __block NWCertificateRef blockCertificate = _certificate;
    __block NWIdentityRef blockIdentity = _identity;
    
    if(_serial == nil){
        _serial = dispatch_queue_create("APNSPushService", DISPATCH_QUEUE_CONCURRENT);
    }
    __block dispatch_queue_t blockSerailQueue = _serial;
    dispatch_async(_serial, ^{
        NSError *error = nil;
        NWEnvironment preferredEnvironment = [self preferredEnvironmentForCertificate:blockCertificate];
        blockHub = [NWHub connectWithDelegate:self identity:blockIdentity environment:NWEnvironmentProduction error:&error];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (blockHub) {
                NSString *summary = [NWSecTools summaryWithCertificate:blockCertificate];
                NSLog(@"Prepare to Send Message wire APNS: %@ (%@)", summary, descriptionForEnvironent(preferredEnvironment));
            } else {
                NSLog(@"Unable to connect: %@", error.localizedDescription);
            }
        });
        
        NSUInteger failed = [blockHub pushPayload:blockPayload token:blockToken];
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC));
        dispatch_after(popTime, blockSerailQueue, ^(void){
            NSUInteger failed2 = failed + [blockHub readFailed];
            if (!failed2) NSLog(@"Payload has been pushed");
        });
    });
}

- (void)notification:(NWNotification *)notification didFailWithError:(NSError *)error{
    dispatch_async(dispatch_get_main_queue(), ^{
        //NSLog(@"failed notification: %@ %@ %lu %lu %lu", notification.payload, notification.token, notification.identifier, notification.expires, notification.priority);
        NSLog(@"Notification error: %@", error.localizedDescription);
        
    });
}

@end
