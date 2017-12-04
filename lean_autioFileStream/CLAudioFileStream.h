//
//  CLAudioFileStream.h
//  lean_autioFileStream
//
//  Created by chen liang on 2017/10/29.
//  Copyright © 2017年 chen liang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "CLParsedAudioData.h"

@class CLAudioFileStream;
@protocol CLAudioFileStreamDelegate <NSObject>
@required
- (void)audioFileStream:(CLAudioFileStream *)audioFileStream audioDataParsed:(NSArray *)audioData;
@optional
- (void)audioFileStreamReadyToProducePackets:(CLAudioFileStream *)audioFileStream;
@end
@interface CLAudioFileStream : NSObject
@property (nonatomic, assign, readonly) AudioFileTypeID fileType;
@property (nonatomic, assign, readonly) BOOL availabel;
@property (nonatomic, assign, readonly) BOOL readyToProducePackets;
@property (nonatomic, weak) id <CLAudioFileStreamDelegate> delegate;

@property (nonatomic, assign, readonly) AudioStreamBasicDescription fromat;
@property (nonatomic, assign, readonly) unsigned long long fileSize;
@property (nonatomic, assign, readonly) NSTimeInterval duration;
@property (nonatomic, assign, readonly) UInt32 bitRate;
@property (nonatomic, assign, readonly) UInt32 maxPacketSize;
@property (nonatomic, assign, readonly) UInt64 audioDataByteCount;

- (instancetype)initWithFileType:(AudioFileTypeID)fileType fileSize:(unsigned long long)fileSize error:(NSError **)erro;

- (BOOL)paraseData:(NSData *)data error:(NSError **)error;

- (SInt64)seekToTime:(NSTimeInterval *)time;
- (NSData *)fetchMagicCookie;
- (void)close;
@end
