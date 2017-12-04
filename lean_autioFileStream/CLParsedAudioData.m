//
//  CLParsedAudioData.m
//  lean_autioFileStream
//
//  Created by chen liang on 2017/10/29.
//  Copyright © 2017年 chen liang. All rights reserved.
//

#import "CLParsedAudioData.h"

@implementation CLParsedAudioData
@synthesize data = _data;
@synthesize packetDescription = _packetDescription;

+ (instancetype)parasedAudioDataWithBytes:(const void *)bytes packetDescription:(AudioStreamPacketDescription)pacektDescription {
    
    return [[self alloc] initWithBytes:bytes packetDescription:pacektDescription];
}
- (instancetype)initWithBytes:(const void *)bytes packetDescription:(AudioStreamPacketDescription)packetDescription {
    if (bytes == NULL || packetDescription.mDataByteSize == 0) {
        return nil;
    }
    self = [super init];
    if (self) {
        _data = [NSData dataWithBytes:bytes length:packetDescription.mDataByteSize];
        _packetDescription = packetDescription;
    }
    return self;
}
@end
