//
//  CLAudioOutputQueue.h
//  lean_autioFileStream
//
//  Created by chen liang on 2017/11/6.
//  Copyright © 2017年 chen liang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
@class CLAudioOutputQueue;
@protocol CLAudioOutputQueue <NSObject>

- (void)audioOutputQueue:(CLAudioOutputQueue *)queue resumeCallback:(AudioQueueBufferRef)buffer;
@end
@interface CLAudioOutputQueue : NSObject
@property (nonatomic, assign, readonly) BOOL availabel;
@property (nonatomic, assign, readonly) AudioStreamBasicDescription format;
@property (nonatomic, assign) float volume;
@property (nonatomic, assign) UInt32 bufferSize;
@property (nonatomic, assign, readonly) BOOL isRunning;
@property (nonatomic, strong) NSOperationQueue *playQueue;

@property (nonatomic, readonly) NSTimeInterval playedTime;

- (instancetype)initWithFormat:(AudioStreamBasicDescription)format bufferSize:(UInt32)bufferSize macgicCookie:(NSData *)macgicCookie;

- (BOOL)playDat:(NSData *)data packetCount:(UInt32)packetCount packetDescriptions:(AudioStreamPacketDescription *)packetDescriptions isEof:(BOOL)isEof;

- (BOOL)pause;
- (BOOL)resume;

- (BOOL)stop:(BOOL)immediately;


/**
 reset queue
 Use wehn seeking

 @return whether is audioqueue successfully reseted
 */
- (BOOL)reset;


/**
 flush data
 Use when audio data reaches eof
 @return whether is audioqueue successfully flushed
 */
- (BOOL)flush;

- (BOOL)setProperty:(AudioQueuePropertyID)propertyID dataSize:(UInt32)dataSize data:(const void *)data error:(NSError **)error;
- (BOOL)getProperty:(AudioQueuePropertyID)propertyID dataSize:(UInt32)dataSize data:(void *)data error:(NSError **)error;
- (BOOL)setParameter:(AudioQueueParameterID)paramterID value:(AudioQueueParameterValue)value error:(NSError **)error;
- (BOOL)getParameter:(AudioQueueParameterID)paramterID value:(AudioQueueParameterValue *)value error:(NSError **)error;

@end
