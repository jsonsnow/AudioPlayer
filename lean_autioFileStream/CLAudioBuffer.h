//
//  CLAudioBuffer.h
//  lean_autioFileStream
//
//  Created by chen liang on 2017/11/11.
//  Copyright © 2017年 chen liang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudioTypes.h>
#import "CLParsedAudioData.h"

@interface CLAudioBuffer : NSObject

+ (instancetype)buffer;
- (void)enqueueData:(CLParsedAudioData *)data;
- (void)enqueueFromDataArray:(NSArray *)dataArray;

- (BOOL)hasData;
- (UInt32)bufferedSize;

//description needs free
- (NSData *)dequeueDataWithSize:(UInt32)requestSize packetCount:(UInt32 *)packetCount descriptions:(AudioStreamPacketDescription **)description;

- (void)clean;
@end
