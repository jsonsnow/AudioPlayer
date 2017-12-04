//
//  CLAudioOutputQueue.m
//  lean_autioFileStream
//
//  Created by chen liang on 2017/11/6.
//  Copyright © 2017年 chen liang. All rights reserved.
//

#import "CLAudioOutputQueue.h"
#import <pthread.h>
const int CLAudioQueueBufferCount = 2;

@interface CLAudioQueueBuffer : NSObject
@property (nonatomic, assign) AudioQueueBufferRef buffer;
@end
@implementation CLAudioQueueBuffer
@end
@implementation CLAudioOutputQueue
{
    @private
    AudioQueueRef _audioQueue;
    NSMutableArray *_buferrs;
    NSMutableArray *_reusableBuffers;
    
    BOOL _started;
    NSTimeInterval _playedTime;
    
    pthread_mutex_t _mutex;
    pthread_cond_t _cond;
}

#pragma mark - init & dealloc
- (instancetype)initWithFormat:(AudioStreamBasicDescription)format bufferSize:(UInt32)bufferSize macgicCookie:(NSData *)macgicCookie {
    self = [super init];
    if (self) {
        _format = format;
        _volume = 1.0f;
        _bufferSize = bufferSize;
        _buferrs = @[].mutableCopy;
        _reusableBuffers = @[].mutableCopy;
        [self _createAudioOutputQueue:macgicCookie];
        [self _mutexInit];
    }
    return self;
}
- (void)dealloc {
    
}
#pragma mark - error
- (void)_errorForOSStatus:(OSStatus)status error:(NSError **)error {
    if (status != noErr && error != NULL) {
        *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
    }
}
#pragma mark - mutex
- (void)_mutexInit {
    pthread_mutex_init(&_mutex, NULL);
    pthread_cond_init(&_cond, NULL);
}

- (void)_mutexDestory {
    pthread_mutex_destroy(&_mutex);
    pthread_cond_destroy(&_cond);
}

- (void)_mutexWait {
    pthread_mutex_lock(&_mutex);
    pthread_cond_wait(&_cond, &_mutex);
    pthread_mutex_unlock(&_mutex);
}

- (void)_mutexSignal {
    
    pthread_mutex_lock(&_mutex);
    pthread_cond_signal(&_cond);
    pthread_mutex_unlock(&_mutex);
}
#pragma mark - audio queue
- (void)_createAudioOutputQueue:(NSData *)magicCookie {
    OSStatus status = AudioQueueNewOutput(&_format, CLAudioQueueOutputCallback, (__bridge void *)self, NULL, NULL ,0,&_audioQueue);
    if (status != noErr) {
        _audioQueue = NULL;
        return;
    }
    status = AudioQueueAddPropertyListener(_audioQueue, kAudioQueueProperty_IsRunning, CLAudioQueuePropertyCallback, (__bridge void *)self);
    if (status != noErr) {
        AudioQueueDispose(_audioQueue, YES);
        _audioQueue = NULL;
        return;
    }
    if (_buferrs.count == 0) {
        for (int i = 0; i < CLAudioQueueBufferCount; ++i) {
            AudioQueueBufferRef buffer;
            status = AudioQueueAllocateBuffer(_audioQueue, _bufferSize, &buffer);
            if (status != noErr) {
                AudioQueueDispose(_audioQueue, YES);
                _audioQueue = NULL;
                break;
            }
            CLAudioQueueBuffer *bufferObj = [[CLAudioQueueBuffer alloc] init];
            bufferObj.buffer = buffer;
            [_buferrs addObject:bufferObj];
            [_reusableBuffers addObject:bufferObj];
        }
    }
#if TARGET_OS_IPHONE
    uint32_t property = kAudioQueueHardwareCodecPolicy_PreferSoftware;
    [self setProperty:kAudioQueueProperty_HardwareCodecPolicy dataSize:sizeof(property) data:&property error:NULL];
#endif
    if (magicCookie) {
        AudioQueueSetProperty(_audioQueue, kAudioQueueProperty_MagicCookie, [magicCookie bytes], (UInt32)[magicCookie length]);
    }
    [self setVolumeParameter];
}

- (void)_disposeAudioOutputQueue {
    if (_audioQueue != NULL) {
        AudioQueueDispose(_audioQueue, true);
        _audioQueue = NULL;
    }
}
- (BOOL)_start {
    OSStatus status = AudioQueueStart(_audioQueue, NULL);
    _started = status == noErr;
    return _started;
}

- (BOOL)resume {
    return [self _start];
}
- (BOOL)pause {
    OSStatus status = AudioQueuePause(_audioQueue);
    _started = NO;
    return status == noErr;
}

- (BOOL)reset {
    OSStatus status = AudioQueueReset(_audioQueue);
    return status == noErr;
}

- (BOOL)flush {
    OSStatus status = AudioQueueFlush(_audioQueue);
    return status == noErr;
}

- (BOOL)stop:(BOOL)immediately {
    OSStatus status = noErr;
    if (immediately) {
        status = AudioQueueStop(_audioQueue, true);
    } else {
        status = AudioQueueStop(_audioQueue, false);
    }
    _started = NO;
    _playedTime = 0;
    return status == noErr;
}
- (BOOL)playDat:(NSData *)data packetCount:(UInt32)packetCount packetDescriptions:(AudioStreamPacketDescription *)packetDescriptions isEof:(BOOL)isEof {
    if ([data length] > _bufferSize) {
        return NO;
    }
    if (_reusableBuffers.count == 0) {
        if (!_started && ![self _start]) {
            return NO;
        }
        [self _mutexWait];
    }
    CLAudioQueueBuffer *bufferObj = [_reusableBuffers firstObject];
    [_reusableBuffers removeObject:bufferObj];
    if (!bufferObj) {
        AudioQueueBufferRef buffer;
        OSStatus status = AudioQueueAllocateBuffer(_audioQueue, _bufferSize, &buffer);
        if (status == noErr) {
            bufferObj = [[CLAudioQueueBuffer alloc] init];
            bufferObj.buffer = buffer;
        } else {
            return NO;
        }
    }
    memcpy(bufferObj.buffer->mAudioData, [data  bytes], [data length]);
    bufferObj.buffer->mAudioDataByteSize = (UInt32)[data length];
    OSStatus status = AudioQueueEnqueueBuffer(_audioQueue, bufferObj.buffer, packetCount, packetDescriptions);
    static int count_i = 0;
    if (status == noErr) {
        if (_reusableBuffers.count == 0 || isEof) {
            NSLog(@"resume buffer is empy we should play audio data:%lu,%d",(unsigned long)_reusableBuffers.count,count_i++);
            if (!_started && ![self _start]) {
                return NO;
            }
        }
    }
    return status == noErr;
}
#pragma mark - property
- (NSTimeInterval)playedTime {
    if (_format.mSampleRate == 0) {
        return 0;
    }
    AudioTimeStamp time;
    OSStatus status = AudioQueueGetCurrentTime(_audioQueue, NULL, &time, NULL);
    if (status == noErr) {
        _playedTime = time.mSampleTime/_format.mSampleRate;
    }
    return _playedTime;
}
- (BOOL)availabel {
    return _audioQueue != NULL;
}
- (void)setVolume:(float)volume {
    _volume = volume;
    [self setVolumeParameter];
}
- (void)setVolumeParameter {
    [self setParameter:kAudioQueueParam_Volume value:_volume error:NULL];
}
#pragma mark - public method
- (BOOL)setProperty:(AudioQueuePropertyID)propertyID dataSize:(UInt32)dataSize data:(const void *)data error:(NSError *__autoreleasing *)error {
    OSStatus status = AudioQueueSetProperty(_audioQueue, propertyID, data, dataSize);
    [self _errorForOSStatus:status error:error];
    return status == noErr;
}
- (BOOL)getProperty:(AudioQueuePropertyID)propertyID dataSize:(UInt32)dataSize data:(void *)data error:(NSError *__autoreleasing *)error {
    OSStatus status = AudioQueueGetProperty(_audioQueue, propertyID, data, &dataSize);
    [self _errorForOSStatus:status error:error];
    return status == noErr;
}

- (BOOL)setParameter:(AudioQueueParameterID)paramterID value:(AudioQueueParameterValue)value error:(NSError *__autoreleasing *)error {
    OSStatus status = AudioQueueSetParameter(_audioQueue, paramterID, value);
    [self _errorForOSStatus:status error:error];
    return status == noErr;
}
- (BOOL)getParameter:(AudioQueueParameterID)paramterID value:(AudioQueueParameterValue *)value error:(NSError *__autoreleasing *)error {
    OSStatus status = AudioQueueGetParameter(_audioQueue, paramterID, value);
    [self _errorForOSStatus:status error:error];
    return status == noErr;
}
#pragma mark - call back
static void CLAudioQueueOutputCallback(void *inClientData,AudioQueueRef inQA,AudioQueueBufferRef inBuffer) {
    CLAudioOutputQueue *audioOutQueue = (__bridge CLAudioOutputQueue *)inClientData;
    [audioOutQueue handlerAudioQueueOutputCallBack:inQA buffer:inBuffer];
}
- (void)handlerAudioQueueOutputCallBack:(AudioQueueRef)audioQueue buffer:(AudioQueueBufferRef)buffer {
  
    for (int i = 0; i < _buferrs.count; i++) {
        if (buffer == [_buferrs[i] buffer]) {
            [_reusableBuffers addObject:_buferrs[i]];
            break;
        }
    }
    [self _mutexSignal];
}
static void CLAudioQueuePropertyCallback(void *inUserData,AudioQueueRef inQA,AudioQueuePropertyID inID) {
    CLAudioOutputQueue *audioOutQueue = (__bridge CLAudioOutputQueue *)inUserData;
    [audioOutQueue handleAudioQueueProperyCallBack:inQA property:inID];
}
- (void)handleAudioQueueProperyCallBack:(AudioQueueRef)audioQueue property:(AudioFilePropertyID)property {
    if (property == kAudioQueueProperty_IsRunning) {
        UInt32 isRunning = 0;
        UInt32 size = sizeof(isRunning);
        AudioQueueGetProperty(audioQueue, property, &isRunning, &size);
        _isRunning = isRunning;
    }
}
@end
