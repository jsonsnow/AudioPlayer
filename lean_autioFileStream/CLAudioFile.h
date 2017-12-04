//
//  CLAudioFile.h
//  lean_autioFileStream
//
//  Created by chen liang on 2017/11/11.
//  Copyright © 2017年 chen liang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioFile.h>

@interface CLAudioFile : NSObject
@property (nonatomic, copy, readonly) NSString *filePath;
@property (nonatomic, assign, readonly) AudioFileTypeID fileType;

@property (nonatomic, assign, readonly) BOOL availabel;

@property (nonatomic, assign, readonly) AudioStreamBasicDescription fromat;
@property (nonatomic, assign, readonly) unsigned long long fileSize;
@property (nonatomic, assign, readonly) NSTimeInterval duration;
@property (nonatomic, assign, readonly) UInt32 bitRate;
@property (nonatomic, assign, readonly) UInt32 maxPacketSize;
@property (nonatomic, assign, readonly) UInt64 audioDataByteCount;

- (instancetype)initWithFilePath:(NSString *)filePath fileType:(AudioFileTypeID)fileType;
- (NSArray *)paraseData:(BOOL *)isEof;
- (NSData *)fetchMagicCookie;
- (void)seekToTime:(NSTimeInterval)time;
- (void)close;
@end
