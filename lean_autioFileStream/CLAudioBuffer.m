//
//  CLAudioBuffer.m
//  lean_autioFileStream
//
//  Created by chen liang on 2017/11/11.
//  Copyright © 2017年 chen liang. All rights reserved.
//

#import "CLAudioBuffer.h"

@interface CLAudioBuffer ()
{
 @private
    NSMutableArray *_bufferBlockArray;
    UInt32 _bufferedSize;
}
@end
@implementation CLAudioBuffer

+ (instancetype)buffer {
    return [[self alloc] init];
}
- (instancetype)init {
    self = [super init];
    if (self) {
        _bufferBlockArray = @[].mutableCopy;
    }
    return self;
}
- (BOOL)hasData {
    return _bufferBlockArray.count > 0;
}
- (UInt32)bufferedSize {
    return _bufferedSize;
}
- (void)enqueueFromDataArray:(NSArray *)dataArray {
    for (CLParsedAudioData *data in dataArray) {
        [self enqueueData:data];
    }
}
- (void)enqueueData:(CLParsedAudioData *)data {
    if ([data isKindOfClass:[CLParsedAudioData class]]) {
        [_bufferBlockArray addObject:data];
        _bufferedSize += data.data.length;
    }
}

- (NSData *)dequeueDataWithSize:(UInt32)requestSize packetCount:(UInt32 *)packetCount descriptions:(AudioStreamPacketDescription **)description {
    if (requestSize == 0 && _bufferBlockArray.count == 0) {
        return nil;
    }
    SInt64 size = requestSize;
    int i = 0;
    for (i = 0; i < _bufferBlockArray.count; ++i) {
        CLParsedAudioData *block = _bufferBlockArray[i];
        SInt64 dataLength = [block.data length];
        if (size > dataLength) {
            size -= dataLength;
        } else {
            if (size < dataLength) {
                i--;
            }
            break;
        }
    }
    if (i < 0) {
        return nil;
    }
    UInt32 count = (i >= _bufferBlockArray.count)?(UInt32)_bufferBlockArray.count:i+1;
    *packetCount = count;
    if (count == 0) {
        return nil;
    }
    if (description != NULL) {
        *description = (AudioStreamPacketDescription *)malloc(sizeof(AudioStreamPacketDescription) * count);
    }
    NSMutableData *retData =[[NSMutableData alloc] init];
    for (int j = 0; j < count; ++j) {
        CLParsedAudioData *block = _bufferBlockArray[j];
        if (description != NULL) {
            AudioStreamPacketDescription desc = block.packetDescription;
            desc.mStartOffset = [retData length];
            (*description)[j] = desc;
        }
        [retData appendData:block.data];
    }
    NSRange removeRange = NSMakeRange(0, count);
    [_bufferBlockArray removeObjectsInRange:removeRange];
    _bufferedSize -= retData.length;
    return retData;
}
- (void)clean {
    _bufferedSize = 0;
    [_bufferBlockArray removeAllObjects];
}
#pragma mark -
- (void)dealloc {
    [_bufferBlockArray removeAllObjects];
}
@end
