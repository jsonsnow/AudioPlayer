//
//  CLSimpleAudioPlayer.m
//  lean_autioFileStream
//
//  Created by chen liang on 2017/11/12.
//  Copyright © 2017年 chen liang. All rights reserved.
//

#import "CLSimpleAudioPlayer.h"
#import "CLAudioFile.h"
#import "CLAudioFileStream.h"
#import "CLAudioOutputQueue.h"
#import "CLAudioBuffer.h"
#import <pthread.h>
#import <AVFoundation/AVFoundation.h>

@interface CLSimpleAudioPlayer ()<CLAudioFileStreamDelegate>
{
@private
    NSThread *_thread;
    pthread_mutex_t _mutex;
    pthread_cond_t _cond;
    
    CLSAPStatus _status;
    
    unsigned long long _fileSize;
    unsigned long long _offset;
    NSFileHandle *_fileHandler;
    
    uint32_t _bufferSize;
    CLAudioBuffer *_buffer;
    
    CLAudioFile *_audioFile;
    CLAudioFileStream *_audioFileStream;
    CLAudioOutputQueue *_audioQueue;
    
    BOOL _started;
    BOOL _pauseRequired;
    BOOL _stopRequired;
    BOOL _pauseByInterrupt;
    BOOL _uingAudioFile;
    
    BOOL _seekRequired;
    NSTimeInterval _seekTime;
    NSTimeInterval _timeingOffset;
}

@end

@implementation CLSimpleAudioPlayer
@dynamic status;
@dynamic duration;
@dynamic progress;

#pragma mark - init & dealloc
- (instancetype)initWithFilePath:(NSString *)filePath fileType:(AudioFileTypeID)fileType {
    self = [super init];
    if (self) {
        _status = CLSAPStatusStopped;
        _filePath = filePath;
        _fileType = fileType;
        _uingAudioFile = YES;
        _fileHandler = [NSFileHandle fileHandleForReadingAtPath:_filePath];
        _fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:_filePath error:NULL] fileSize];
        if (_fileHandler && _fileSize > 0) {
            _buffer = [CLAudioBuffer buffer];
        } else {
            [_fileHandler closeFile];
            _failed = YES;
        }
    }
    return self;
}
- (void)dealloc {
    [self cleanup];
    [_fileHandler closeFile];
}

- (void)cleanup {
    _offset = 0;
    [_fileHandler seekToFileOffset:0];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionInterruptionNotification object:nil];
    [_buffer clean];
    
    _uingAudioFile = NO;
    [_audioFileStream close];
    _audioFileStream = nil;
    
    [_audioFile close];
    _audioFile = nil;
    
    [_audioQueue stop:YES];
    _audioQueue = nil;
    
    [self _mutexDestory];
    
    _started = NO;
    _timeingOffset = 0;
    _seekTime = 0;
    _seekRequired = NO;
    _pauseRequired = NO;
    _stopRequired = NO;
    
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

#pragma mark - status
- (BOOL)isPlayingOrWaiting {
    return self.status == CLSAPStatusPalying || self.status == CLSAPStatusWaiting||self.status == CLSAPStatusFlushing;
}
- (CLSAPStatus)status {
    return _status;
}

- (void)setStatusInternal:(CLSAPStatus)status {
    if (_status == status) {
        return;
    }
    [self willChangeValueForKey:@"status"];
    _status = status;
    [self didChangeValueForKey:@"status"];
}

#pragma mark - thread
- (BOOL)createAudioQueue {
    if (_audioQueue) {
        return YES;
    }
    NSTimeInterval duration = self.duration;
    UInt64 audioDataByteCount = _uingAudioFile?_audioFile.audioDataByteCount:_audioFileStream.audioDataByteCount;
    _bufferSize = 0;
    if (duration != 0) {
        _bufferSize = (0.2 /duration) * audioDataByteCount;
    }
    if (_bufferSize > 0) {
        AudioStreamBasicDescription format = _uingAudioFile?_audioFile.fromat:_audioFileStream.fromat;
        NSData *magicCookie = _uingAudioFile?[_audioFile fetchMagicCookie]:[_audioFileStream fetchMagicCookie];
        _audioQueue = [[CLAudioOutputQueue alloc] initWithFormat:format bufferSize:_bufferSize macgicCookie:magicCookie];
        if (!_audioQueue.availabel) {
            _audioQueue = nil;
            return NO;
        }
    }
    return YES;
}

-(void)threadMain {
    _failed = YES;
    NSError *error = nil;
    if ([[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:NULL]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(interruptHandler:) name:AVAudioSessionInterruptionNotification object:nil];
        if ([[AVAudioSession sharedInstance] setActive:YES error:NULL]) {
            
            _audioFileStream = [[CLAudioFileStream alloc] initWithFileType:_fileType fileSize:_fileSize error:&error];
            if (!error) {
                _failed = NO;
                _audioFileStream.delegate = self;
            }
        }
        
    }
    if (_failed) {
        [self cleanup];
        return;
    }
    
    [self setStatusInternal:CLSAPStatusWaiting];
    BOOL isEof = NO;
    while (self.status != CLSAPStatusStopped && !_failed && _started) {
        
        @autoreleasepool {
            if (_uingAudioFile) {
                if (!_audioFile) {
                    _audioFile = [[CLAudioFile alloc] initWithFilePath:_filePath fileType:_fileType];
                    [_audioFile seekToTime:_seekTime];
                }
                if ([_buffer bufferedSize] < _bufferSize || _audioQueue) {
                    NSArray *parseData = [_audioFile paraseData:&isEof];
                    if (parseData) {
                        [_buffer enqueueFromDataArray:parseData];
                    } else {
                        _failed = YES;
                        break;
                    }
                }
            } else {
                
                if (_offset < _fileSize && (!_audioFileStream.readyToProducePackets ||[_buffer bufferedSize] < _bufferSize || !_audioQueue)) {
                    NSData *data = [_fileHandler readDataOfLength:1000];
                    _offset += [data length];
                    if (_offset >= _fileSize) {
                        isEof = YES;
                    }
                    [_audioFileStream paraseData:data error:&error];
                    if (error) {
                        _uingAudioFile = YES;
                        continue;
                    }
                    
                }
            }
            
            if (_audioFileStream.readyToProducePackets || _uingAudioFile) {
                
                if (![self createAudioQueue]) {
                    _failed = YES;
                    break;
                }
                if (!_audioQueue) {
                    continue;
                }
                if (self.status == CLSAPStatusFlushing && !_audioQueue.isRunning) {
                    break;
                }
                //stop
                if (_stopRequired)
                {
                    _stopRequired = NO;
                    _started = NO;
                    [_audioQueue stop:YES];
                    break;
                }
                
                //pause
                if (_pauseRequired)
                {
                    [self setStatusInternal:CLSAPStatusPaused];
                    [_audioQueue pause];
                    [self _mutexWait];
                    _pauseRequired = NO;
                }
                
                //play
                if ([_buffer bufferedSize] >= _bufferSize || isEof)
                {
                    if (isEof) {
                        NSLog(@"isEof");
                    }
                    UInt32 packetCount;
                    AudioStreamPacketDescription *desces = NULL;
                    NSData *data = [_buffer dequeueDataWithSize:_bufferSize packetCount:&packetCount descriptions:&desces];
                    if (packetCount != 0)
                    {
                        [self setStatusInternal:CLSAPStatusPalying];
                        _failed = ![_audioQueue playDat:data packetCount:packetCount packetDescriptions:desces isEof:isEof];
                        free(desces);
                        if (_failed)
                        {
                            break;
                        }
                        
                        if (![_buffer hasData] && isEof && _audioQueue.isRunning)
                        {
                            [_audioQueue stop:NO];
                            [self setStatusInternal:CLSAPStatusFlushing];
                        }
                    }
                    else if (isEof)
                    {
                        //wait for end
                        if (![_buffer hasData] && _audioQueue.isRunning)
                        {
                            [_audioQueue stop:NO];
                            [self setStatusInternal:CLSAPStatusFlushing];
                        }
                    }
                    else
                    {
                        _failed = YES;
                        break;
                    }
                }
                
                //seek
                if (_seekRequired && self.duration != 0)
                {
                    [self setStatusInternal:CLSAPStatusWaiting];
                    
                    _timeingOffset = _seekTime - _audioQueue.playedTime;
                    [_buffer clean];
                    if (_uingAudioFile)
                    {
                        [_audioFile seekToTime:_seekTime];
                    }
                    else
                    {
                        _offset = [_audioFileStream seekToTime:&_seekTime];
                        [_fileHandler seekToFileOffset:_offset];
                    }
                    _seekRequired = NO;
                    [_audioQueue reset];
                }
            }
        }
    }
}
#pragma mark - stream delegate
- (void)audioFileStream:(CLAudioFileStream *)audioFileStream audioDataParsed:(NSArray *)audioData {
    [_buffer enqueueFromDataArray:audioData];
}
- (NSTimeInterval)progress {
    if (!_seekRequired) {
        return _seekTime;
    }
    return _timeingOffset + _audioQueue.playedTime;
}
- (void)setProgress:(NSTimeInterval)progress {
    _seekRequired = YES;
    _seekTime = progress;
}
- (NSTimeInterval)duration {
    return _uingAudioFile?_audioFile.duration:_audioFileStream.duration;
}
#pragma mark - public method
- (void)play {
    if (!_started) {
        _started = YES;
        [self _mutexInit];
        _thread = [[NSThread alloc] initWithTarget:self selector:@selector(threadMain) object:nil];
        [_thread start];
    } else {
        if (_status == CLSAPStatusPaused|| _pauseRequired) {
            _pauseByInterrupt = NO;
            _pauseRequired = NO;
            if ([[AVAudioSession sharedInstance] setActive:YES error:NULL]) {
                [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:NULL];
                [self _resume];
            }
        }
    }
}
- (void)_resume {
    [_audioQueue resume];
    [self _mutexSignal];
}
- (void)pause {
    if (self.isPlayingOrWaiting && self.status != CLSAPStatusFlushing) {
        _pauseRequired = YES;
    }
}
- (void)stop {
    _stopRequired = YES;
    [self _mutexSignal];
}
#pragma mark - interrupt
- (void)interruptHandler:(NSNotification *)notifation {
    
}
@end
