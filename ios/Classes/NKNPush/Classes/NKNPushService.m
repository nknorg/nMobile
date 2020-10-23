//
//  NKNPushService.m
//  Runner
//
//  Created by  Rebloom on 2020/9/21.
//  Copyright © 2020 The Chromium Authors. All rights reserved.
//

#import "NKNPushService.h"

#import "NWSecTools.h"

#define Push_Developer   "gateway.sandbox.push.apple.com"
#define Push_Production  "gateway.push.apple.com"

// If you want to add APNS, locate your own p12 or .cer file here
#define APNSPushFileName            @""
#define APNSPushPassword            @""

@implementation NKNPushService 

static NKNPushService * sharedService = nil;
+ (NKNPushService *)sharedService{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedService = [[NKNPushService alloc] init];
    });
    return sharedService;
}

- (void)connectAPNS{
    _serial = dispatch_queue_create("NKNPushService", DISPATCH_QUEUE_SERIAL);
    
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
    dispatch_async(_serial, ^{
        NSError *error = nil;
        NWEnvironment preferredEnvironment = [self preferredEnvironmentForCertificate:_certificate];
        NWHub *hub = [NWHub connectWithDelegate:self identity:_identity environment:preferredEnvironment error:&error];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (hub) {
                NSString *summary = [NWSecTools summaryWithCertificate:_certificate];
                NSLog(@"Connected to APN: %@ (%@)", summary, descriptionForEnvironent(NWEnvironmentProduction));
                _hub = hub;
            }
            else
            {
                NSLog(@"Unable to connect: %@", error.localizedDescription);
            }
        });
    });
}

-(NWEnvironment)preferredEnvironmentForCertificate:(NWCertificateRef)certificate
{
    NWEnvironmentOptions environmentOptions = [NWSecTools environmentOptionsForCertificate:certificate];
    
    return (environmentOptions & NWEnvironmentOptionSandbox) ? NWEnvironmentSandbox : NWEnvironmentProduction;
}

- (void)pushContent:(NSString *)pushContent token:(NSString *)pushToken{
//    NSString *payload = [NSString stringWithFormat:@"{\"aps\":{\"alert\":\"%@\",\"badge\":1,\"sound\":\"default\"}}", pushContent];
    NSLog(@"Pushing..");
    NSLog(@"Push Content %@ With Token %@",pushContent,pushToken);
    
//    if (_hub){
//        [_hub disconnect];
//    }
    
    NSString *payload = [NSString stringWithFormat:@"{\"aps\":{\"alert\":\"%@\",\"badge\":1,\"sound\":\"default\"}}", pushContent];
    NSString *token = pushToken;
    dispatch_async(_serial, ^{
        NSError *error = nil;
        NWEnvironment preferredEnvironment = [self preferredEnvironmentForCertificate:_certificate];
        _hub = [NWHub connectWithDelegate:self identity:_identity environment:preferredEnvironment error:&error];

//        NSURL *url = [NSBundle.mainBundle URLForResource:@"nkn.p12" withExtension:nil];
//        NSData *pkcs12 = [NSData dataWithContentsOfURL:url];
//        NWHub * hub = [NWHub connectWithDelegate:self PKCS12Data:pkcs12 password:@"nkn_5905aa60af025ac8_NKN" environment:preferredEnvironment error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (_hub) {
                NSString *summary = [NWSecTools summaryWithCertificate:_certificate];
                NSLog(@"Connected to APN: %@ (%@)", summary, descriptionForEnvironent(NWEnvironmentProduction));
//                _hub = hub;
            }
            else
            {
                NSLog(@"Unable to connect: %@", error.localizedDescription);
            }
        });
        

        NSUInteger failed = [_hub pushPayload:payload token:token];
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC));
        dispatch_after(popTime, _serial, ^(void){
            NSUInteger failed2 = failed + [_hub readFailed];
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
