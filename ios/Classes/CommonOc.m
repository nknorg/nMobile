//
//  CommonOc.m
//  Runner
//
//  Created by 蒋治国 on 2021/6/7.
//

#import "CommonOc.h"

#import <Photos/Photos.h>
#import <Nkn/Nkn.h>
#import <Flutter/Flutter.h>

@implementation CommonOc

-(instancetype)init{
    return self;
}

-(void)saveImageWithImageName:(NSString*) imageName imageData:(FlutterStandardTypedData*) imageData albumName:(NSString *)albumName overwriteFile:(BOOL)overwriteFile {
    __block NSString* localId;
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        PHAssetCreationRequest *assetChangeRequest = [PHAssetCreationRequest creationRequestForAsset];
        PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
        options.originalFilename = imageName;
        options.shouldMoveFile = overwriteFile;
        [assetChangeRequest addResourceWithType:PHAssetResourceTypePhoto data:imageData.data options:options];
        PHObjectPlaceholder *placeholder = [assetChangeRequest placeholderForCreatedAsset];
        localId = placeholder.localIdentifier;
        if(![albumName isEqual:[NSNull null]]){
            PHAssetCollectionChangeRequest *collectionRequest;
            PHAssetCollection *assetCollection = [self getCurrentPhotoCollectionWithTitle:albumName];
            if (assetCollection) {
                collectionRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:assetCollection];
            } else {
                collectionRequest = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:albumName];
            }
            [collectionRequest addAssets:@[placeholder]];
        }
    } completionHandler:^(BOOL success, NSError *error) {
//        if(error !=  nil){
//            result([FlutterError errorWithCode:[NSString stringWithFormat:@"%ld",error.code] message:error.description details:error.localizedFailureReason]);
//            return;
//        }
//        if (success) {
//            PHFetchResult* assetResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[localId] options:nil];
//            PHAsset *asset = [assetResult firstObject];
//            [asset requestContentEditingInputWithOptions:nil completionHandler:^(PHContentEditingInput * _Nullable contentEditingInput, NSDictionary * _Nonnull info) {
//                result(@YES);
//            }];
//        } else {
//            result(@NO);
//        }
    }];
}

- (PHAssetCollection *)getCurrentPhotoCollectionWithTitle:(NSString *)collectionName {
    for (PHAssetCollection *assetCollection in [self getAlbumGroup]) {
        if ([assetCollection.localizedTitle containsString:collectionName]) {
            return assetCollection;
        }
    }
    return nil;
}

-(PHFetchResult<PHAssetCollection *> *)getAlbumGroup{
    return [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
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
//            NSLog(@"byteLength______%lu",byteLength);
        }
        else{
            [encodeBytes set:i b:nil];
        }
    }
    BOOL result = [encoder reconstructBytesArray:encodeBytes error:&error];
    if (result == true){
//        NSLog(@"reconstructBytesArray success");
        NSMutableData * joinedData = [[NSMutableData alloc] init];
        if (error == nil){
//            NSLog(@"joinBytesArray success");
            for (int k = 0; k < dataPiece; k++){
                NSData * pData = [encodeBytes get:k];
//                NSLog(@"pData byteLength______%lu",pData.length);
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
            
//    NSLog(@"BeforeSplitDataString is____%lu",dataBytesString.length);
    NSData * splitData = [dataBytesString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSInteger combineLength = dataPiece+parityPiece;
    ReedsolomonBytesArray * encodeBytes = [[ReedsolomonBytesArray alloc] init:combineLength];
    encodeBytes = [encoder splitBytesArray:splitData error:&error];
    [encoder encodeBytesArray:encodeBytes error:&error];
    
    NSMutableArray * resultArray = [NSMutableArray array];
    
    if (error){
        NSLog(@"Encode Error,%@",error.description);
    }
    else{
        for (int i = 0; i < encodeBytes.len; i++){
            NSData * pData = [encodeBytes get:i];
            [resultArray addObject:pData];
//            NSLog(@"pData hexString Length is___%lu",pData.length);
//            NSLog(@"pData hash is___%lu",pData.hash);
        }
    }
    return resultArray;
}

@end
