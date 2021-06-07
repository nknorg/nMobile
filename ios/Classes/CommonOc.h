//
//  CommonOc.h
//  Runner
//
//  Created by 蒋治国 on 2021/6/7.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CommonOc : NSObject
{
}

- (NSString *)combinePieces:(NSArray *)dataPieces dataShard:(NSInteger)dataPiece parityShards:(NSInteger)parityPiece bytesLength:(NSInteger)bytesLength;

- (NSArray<NSData *> *)intoPieces:(NSString *)dataBytesString dataShard:(NSInteger)dataPiece parityShards:(NSInteger)parityPiece;

@end

NS_ASSUME_NONNULL_END
