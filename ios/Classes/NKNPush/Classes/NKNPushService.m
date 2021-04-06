//
//  NKNPushService.m
//  Runner
//
//  Created by  Rebloom on 2020/9/21.
//  Copyright © 2020 The Chromium Authors. All rights reserved.
//

#import "NKNPushService.h"

#import "NWSecTools.h"

#import <Nkn/Nkn.h>

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
        sharedService = [[self alloc] init];
    });
    return sharedService;
}

- (void)connectAPNS{
    if(_serial == nil){
        _serial = dispatch_queue_create("NKNPushService", DISPATCH_QUEUE_CONCURRENT);
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

- (void)pushContentToFCM:(NSString *)pushContent byToken:(NSString *)fcmToken
{
    static NSString * FCM_SEND_V0_URL = @"https://fcm.googleapis.com/fcm/send";
    static NSString * v0TokenString = @"AAAA5GLjU2E:APA91bF6_GGE0OgxHpfTRP7OQYk71WxKRNTE0OZifagqDHy4O5E0HUTY5-cxJfWzk7_lzNCKbj9WaJRUWeEtbIq6RMeeB_OVKz_FFWbi7BnG54Q4dDnY6s2ePd-BBgKQWoJUU8-FM2xZ";
    NSString * keyString = [NSString stringWithFormat:@"key=%@",v0TokenString];
    
    NSMutableURLRequest * mRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:FCM_SEND_V0_URL]];
    [mRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [mRequest setValue:keyString forHTTPHeaderField:@"Authorization"];
    [mRequest setHTTPMethod:@"POST"];

    NSMutableDictionary * postBody = [NSMutableDictionary dictionary];
    NSMutableDictionary * postParams = [NSMutableDictionary dictionary];
    [postParams setObject:@"New Message!" forKey:@"title"];
    [postParams setObject:pushContent forKey:@"body"];
    [postBody setObject:postParams forKey:@"notification"];
    [postBody setObject:fcmToken forKey:@"to"];
    NSData * postData = [NSJSONSerialization dataWithJSONObject:postBody options:NSJSONWritingPrettyPrinted error:nil];
    [mRequest setHTTPBody:postData];
    
    if (self.session == nil){
        self.session = [NSURLSession sharedSession];
    }
    
    self.dataTask = [self.session dataTaskWithRequest:mRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (data == nil){
            return;
        }
        NSDictionary *dict=[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
        NSString * code = [[dict objectForKey:@"statusCode"] description];
        NSLog(@"response String = %@",code);
        NSLog(@"response String = %@",dict);
        NSLog(@"response String = %@",response);
    }];
    [self.dataTask resume];
}

- (void)pushContent:(NSString *)pushContent token:(NSString *)pushToken{
    NSLog(@"Pushing..");
    NSLog(@"Push Content %@ With Token %@",pushContent,pushToken);
    
    NSString *payload = [NSString stringWithFormat:@"{\"aps\":{\"alert\":\"%@\",\"badge\":1,\"sound\":\"default\"}}", pushContent];
//    NSString *token = pushToken;
    
    __block NSString * blockPayload = payload;
    __block NSString * blockToken = pushToken;
    __block NWHub * blockHub = _hub;
    __block NWCertificateRef blockCertificate = _certificate;
    __block NWIdentityRef blockIdentity = _identity;
    
    if(_serial == nil){
        _serial = dispatch_queue_create("NKNPushService", DISPATCH_QUEUE_CONCURRENT);
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
            }
            else
            {
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

- (NSString *)combinePieces:(NSArray *)dataPieces dataShard:(NSInteger)dataPiece parityShards:(NSInteger)parityPiece bytesLength:(NSInteger)tBytesLength{
    NSError *error = nil;
    ReedsolomonEncoder * encoder = [[ReedsolomonEncoder alloc] init];
    encoder = (ReedsolomonEncoder *)ReedsolomonNewDefault(dataPiece, parityPiece, &error);

    NSInteger byteLength = 0;
    for (int i = 0; i < dataPieces.count; i++){
        NSData * pData = [dataPieces objectAtIndex:i];
        if (pData.length > 0){
            byteLength = pData.length;
        }
    }

    NSInteger combineLength = dataPiece+parityPiece;
    ReedsolomonBytesArray * encodeBytes = [[ReedsolomonBytesArray alloc] init:combineLength];

    for (int i = 0; i < dataPieces.count; i++){
        NSData * pData = [dataPieces objectAtIndex:i];
        if (pData.length > 0){
            NSMutableData * nData = [[NSMutableData alloc] initWithBytes:pData.bytes length:byteLength];
            [encodeBytes set:i b:nData];
            NSLog(@"byteLength______%lu",byteLength);
        }
        else{
            [encodeBytes set:i b:nil];
        }
    }
    BOOL result = [encoder reconstructBytesArray:encodeBytes error:&error];
    if (result == true){
        NSLog(@"reconstructBytesArray success");
        NSMutableData * joinedData = [[NSMutableData alloc] init];
        if (error == nil){
            NSLog(@"joinBytesArray success");
            for (int k = 0; k < dataPiece; k++){
                NSData * pData = [encodeBytes get:k];
                NSLog(@"pData byteLength______%lu",pData.length);
                [joinedData appendData:pData];
            }

            if (joinedData.length > tBytesLength){
                joinedData = [NSMutableData dataWithData:[joinedData subdataWithRange:NSMakeRange(0, tBytesLength)]];
            }
            NSString * resultString = [[NSString alloc] initWithData:joinedData encoding:NSUTF8StringEncoding];
            return resultString;
        }
        else{
            NSLog(@"joinBytesArray Error___%@",error.description);
        }
    }
    else{
        NSLog(@"reconstructBytesArray failed__%@",error.description);
    }
    return @"";
}

- (NSArray<NSData *> *)intoPieces:(NSString *)dataBytesString dataShard:(NSInteger)dataPiece parityShards:(NSInteger)parityPiece{
    NSError *error = nil;
    ReedsolomonEncoder * encoder = [[ReedsolomonEncoder alloc] init];
    encoder = (ReedsolomonEncoder *)ReedsolomonNewDefault(dataPiece, parityPiece, &error);
            
    NSMutableArray * resultArray = [NSMutableArray array];
    
    NSLog(@"BeforeSplitDataString is____%lu",dataBytesString.length);
    NSData * splitData = [dataBytesString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSInteger combineLength = dataPiece+parityPiece;
    ReedsolomonBytesArray * encodeBytes = [[ReedsolomonBytesArray alloc] init:combineLength];
    encodeBytes = [encoder splitBytesArray:splitData error:&error];
    [encoder encodeBytesArray:encodeBytes error:&error];
    
    if (error){
        NSLog(@"Encode Error,%@",error.description);
    }
    else{
        for (int i = 0; i < encodeBytes.len; i++){
            NSData * pData = [encodeBytes get:i];
            [resultArray addObject:pData];
            NSLog(@"pData hexString Length is___%lu",pData.length);
            NSLog(@"pData hash is___%lu",pData.hash);
        }
    }
    return resultArray;
}

#pragma mark-----将十六进制数据转换成NSData
- (NSData *)dataWithHexString:(NSString*)str{
    if (!str || [str length] == 0) {
        return nil;
    }
    
    NSMutableData *hexData = [[NSMutableData alloc] initWithCapacity:8];
    NSRange range;
    if ([str length] % 2 == 0) {
        range = NSMakeRange(0, 2);
    } else {
        range = NSMakeRange(0, 1);
    }
    for (NSInteger i = range.location; i < [str length]; i += 2) {
        unsigned int anInt;
        NSString *hexCharStr = [str substringWithRange:range];
        NSScanner *scanner = [[NSScanner alloc] initWithString:hexCharStr];
        
        [scanner scanHexInt:&anInt];
        NSData *entity = [[NSData alloc] initWithBytes:&anInt length:1];
        [hexData appendData:entity];
        
        range.location += range.length;
        range.length = 2;
    }
    return hexData;
    
}

#pragma mark - 将传入的NSData类型转换成NSString并返回
- (NSString *)hexStringWithData:(NSData *)data
{
    const unsigned char* dataBuffer = (const unsigned char*)[data bytes];
    if(!dataBuffer){
        return nil;
    }
    NSUInteger dataLength = [data length];
    NSMutableString* hexString = [NSMutableString stringWithCapacity:(dataLength * 2)];
    for(int i = 0; i < dataLength; i++){
        [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)dataBuffer[i]]];
    }
    NSString* result = [NSString stringWithString:hexString];
    return result;
}

@end
