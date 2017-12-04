//
//  CLAudioFile.m
//  lean_autioFileStream
//
//  Created by chen liang on 2017/11/11.
//  Copyright © 2017年 chen liang. All rights reserved.
//

#import "CLAudioFile.h"
#import <AudioToolbox/AudioToolbox.h>
#import "CLParsedAudioData.h"
static const UInt32 packetPerRead = 15;
@interface CLAudioFile ()
{
    @private
    SInt64 _pcaketOffset;
    NSFileHandle *_fileHandler;
    SInt64 _dataOffset;
    NSTimeInterval _packetDuration;
    AudioFileID _audioFileID;
}
@end
@implementation CLAudioFile
@synthesize filePath = _filePath;
@synthesize fileType = _fileType;
@synthesize fileSize = _fileSize;
@synthesize duration = _duration;
@synthesize bitRate = _bitRate;
@synthesize fromat = _fromat;
@synthesize maxPacketSize = _maxPacketSize;
@synthesize audioDataByteCount = _audioDataByteCount;

#pragma mark - init & dealloc
- (instancetype)initWithFilePath:(NSString *)filePath fileType:(AudioFileTypeID)fileType {
    
    self = [super init];
    if (self) {
        _filePath = filePath;
        _fileType = fileType;
        _fileHandler = [NSFileHandle fileHandleForReadingAtPath:filePath];
        _fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:_filePath error:NULL] fileSize];
        if (_fileHandler && _fileSize > 0) {
            if ([self _openAudioFile]) {
                [self _fetchFormatInfo];
            }
            
        } else {
            [_fileHandler closeFile];
        }
    }
    return self;
}

#pragma mark - audiofile
- (BOOL)_openAudioFile {
    OSStatus status = AudioFileOpenWithCallbacks((__bridge void *)self,
                                                 CLAudioFileReadCallBack,
                                                 NULL,
                                                 CLAudioFileGetSizeCallBack,
                                                 NULL,
                                                 _fileType,
                                                 &_audioFileID);
    if (status != noErr) {
        _audioFileID = NULL;
        return NO;
    }
    return YES;
}
- (void)_fetchFormatInfo {
    uint32_t formatListSize;
    OSStatus status = AudioFileGetPropertyInfo(_audioFileID, kAudioFilePropertyFormatList, &formatListSize, NULL);
    if (status == noErr) {
        BOOL found = NO;
        AudioFormatListItem *foramtList = malloc(formatListSize);
        OSStatus status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyFormatList, &formatListSize, foramtList);
        if (status == noErr) {
            uint32_t supportedFormatsSize;
            status = AudioFormatGetPropertyInfo(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &supportedFormatsSize);
            if (status != noErr) {
                free(foramtList);
                [self _closeAudioFile];
                return;
            }
            uint32_t supportedFormatCount = supportedFormatsSize/sizeof(OSType);
            OSType *supportedFormats = (OSType *)malloc(supportedFormatsSize);
            status = AudioFormatGetProperty(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &supportedFormatsSize, supportedFormats);
            if (status != noErr) {
                free(foramtList);
                free(supportedFormats);
                [self _closeAudioFile];
                return;
            }
            for (int i = 0; i * sizeof(AudioFormatListItem) < formatListSize; ++i) {
                AudioStreamBasicDescription format = foramtList[i].mASBD;
                for (uint32_t j = 0; j < supportedFormatCount; j++) {
                    if (format.mFormatID == supportedFormats[j]) {
                        _fromat = format;
                        found = YES;
                        break;
                    }
                }
            }
            free(supportedFormats);
        }
        free(foramtList);
        if (!found) {
            [self _closeAudioFile];
            return;
        } else {
            [self _calculatePacketDuration];
        }
    }
    uint32_t size = sizeof(_bitRate);
    status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyBitRate, &size, &_bitRate);
    if (status != noErr) {
        [self _closeAudioFile];
        return;
    }
    size = sizeof(_dataOffset);
    status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyDataOffset, &size, &_dataOffset);
    if (status != noErr) {
        [self _closeAudioFile];
        return;
    }
    _audioDataByteCount = _fileSize - _dataOffset;
    
    size = sizeof(_duration);
    status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyEstimatedDuration, &size, &_duration);
    if (status != noErr) {
        [self _calculateDuration];
    }
    
    size = sizeof(_maxPacketSize);
    status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyPacketSizeUpperBound, &size, &_maxPacketSize);
    if (status != noErr || _maxPacketSize == 0) {
        status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyMaximumPacketSize, &size, &_maxPacketSize);
        if (status != noErr) {
            [self _closeAudioFile];
            return;
        }
    }
}
- (NSData *)fetchMagicCookie {
    uint32_t cookieSize;
    OSStatus status = AudioFileGetPropertyInfo(_audioFileID, kAudioFilePropertyMagicCookieData, &cookieSize, NULL);
    if (status != noErr) {
        return nil;
    }
    void *cookieData = malloc(cookieSize);
    status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyMagicCookieData, &cookieSize, cookieData);
    if (status != noErr) {
        return nil;
    }
    NSData *cookie = [NSData dataWithBytes:cookieData length:cookieSize];
    free(cookieData);
    return cookie;
}
- (void)_closeAudioFile {
    if (self.availabel) {
        AudioFileClose(_audioFileID);
        _audioFileID = NULL;
    }
}
- (void)close {
    [self _closeAudioFile];
}
- (void)_calculatePacketDuration {
    if (_fromat.mSampleRate > 0) {
        _packetDuration = _fromat.mFramesPerPacket / _fromat.mSampleRate;
    }
}
- (void)_calculateDuration {
    if (_fileSize > 0 && _bitRate > 0) {
        _duration = ((_fileSize - _dataOffset) * 8.0)/_bitRate;
    }
}
- (NSArray *)paraseData:(BOOL *)isEof {
    uint32_t ioNumPackets = packetPerRead;
    uint32_t ioNumBytes = ioNumPackets * _maxPacketSize;
    void *outBuffer = (void *)malloc(ioNumBytes);
    AudioStreamPacketDescription *outPacketDescription = NULL;
    OSStatus status = noErr;
    if (_fromat.mFormatID != kAudioFormatLinearPCM) {
        uint32_t descSize = sizeof(AudioStreamPacketDescription) * ioNumPackets;
        outPacketDescription = (AudioStreamPacketDescription *)malloc(descSize);
        status = AudioFileReadPacketData(_audioFileID, false, &ioNumBytes, outPacketDescription, _pcaketOffset, &ioNumPackets, outBuffer);
    } else {
        status = AudioFileReadPackets(_audioFileID, false, &ioNumBytes, outPacketDescription, _pcaketOffset, &ioNumPackets, outBuffer);
    }
    if (status != noErr) {
        *isEof = status == kAudioFileEndOfFileError;
        free(outBuffer);
        return nil;
    }
    if (ioNumBytes == 0) {
        *isEof = YES;
    }
    _pcaketOffset += ioNumPackets;
    if (ioNumPackets > 0) {
        NSMutableArray *paredDataArray = @[].mutableCopy;
        for (int i = 0; i < ioNumPackets; i++) {
            AudioStreamPacketDescription packetDescription;
            if (outPacketDescription) {
                packetDescription = outPacketDescription[i];
            } else {
                packetDescription.mStartOffset = i * _fromat.mBytesPerPacket;
                packetDescription.mDataByteSize = _fromat.mBytesPerPacket;
                packetDescription.mVariableFramesInPacket = _fromat.mFramesPerPacket;
            }
            CLParsedAudioData *paredData = [CLParsedAudioData parasedAudioDataWithBytes:outBuffer + packetDescription.mStartOffset packetDescription:packetDescription];
            if (paredData) {
                [paredDataArray addObject:paredData];
            }
        }
        return paredDataArray;
    }
    return nil;
}
- (void)seekToTime:(NSTimeInterval)time {
    _pcaketOffset = floor(time/_packetDuration);
}
- (UInt32)availableDataLengthAtOffset:(SInt64)inPostion maxLength:(UInt32)requetCount {
    if ((inPostion + requetCount) > _fileSize) {
        if (inPostion > _fileSize) {
            return 0;
        } else {
            return (UInt32)(_fileSize -inPostion);
        }
    } else {
        return requetCount;
    }
}
- (NSData *)dataAtOffset:(SInt64)inPostion length:(UInt32)length {
    [_fileHandler seekToFileOffset:inPostion];
    return [_fileHandler readDataOfLength:length];
}
#pragma mark - callback
static OSStatus CLAudioFileReadCallBack(void *inClientData,SInt64 inPosition,UInt32 reqeustCount,void *buffer,UInt32 *actualCount) {
    CLAudioFile *audioFile = (__bridge CLAudioFile *)inClientData;
    *actualCount = [audioFile availableDataLengthAtOffset:inPosition maxLength:reqeustCount];
    if (*actualCount > 0) {
        NSData *data = [audioFile dataAtOffset:inPosition length:*actualCount];
        memcpy(buffer, [data bytes], [data length]);
    }
    return noErr;
}

static SInt64 CLAudioFileGetSizeCallBack(void *inClientData) {
    CLAudioFile *audioFile = (__bridge CLAudioFile *)inClientData;
    return audioFile.fileSize;
}
#pragma mark - getter and setter
- (BOOL)availabel {
    return _audioFileID != NULL;
}
@end
