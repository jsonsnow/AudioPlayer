//
//  CLAudioFileStream.m
//  lean_autioFileStream
//
//  Created by chen liang on 2017/10/29.
//  Copyright © 2017年 chen liang. All rights reserved.
//

#import "CLAudioFileStream.h"

#define BitRateEstimationMaxPackets 5000
#define BitRateEstimationMinPackets 10
@interface CLAudioFileStream ()
{
    @private
    BOOL _discontinous;
    AudioFileStreamID _audioFileStreamID;
    SInt64 _dataOffset;
    NSTimeInterval _packetDuration;
    UInt64 _processdPacketsCount;
    UInt64 _processedPacketsSizeTotal;
}
- (void)handleAudiFileStreamProperty:(AudioFileStreamPropertyID)propertyID;
- (void)handleAudioFileStreamPackets:(const void *)packets
                       numberOfBytes:(UInt32)numberOfBytes
                     numberOfPackets:(UInt32)numberOfPackets
                  packetDescriptions:(AudioStreamPacketDescription *)packetDescription;
@end
#pragma mark -- static callbacks
static void CLAudioFileStreamPropertyListener(void *inClientData,
                                              AudioFileStreamID inAudioFileStream,
                                              AudioFileStreamPropertyID inPropertyID,
                                              UInt32 *ioFlags) {
    CLAudioFileStream *audioFileStream = (__bridge CLAudioFileStream *)inClientData;
    [audioFileStream handleAudiFileStreamProperty:inPropertyID];
    
}
static void CLAudioFileStreamPacketsCallback(void *inClient,
                                             UInt32 inNumberBytes,
                                             UInt32 inNumberPackets,
                                             const void *inInputData,
                                             AudioStreamPacketDescription *inPacketDescriptions) {
    CLAudioFileStream *audioFileStream = (__bridge CLAudioFileStream *)inClient;
    [audioFileStream handleAudioFileStreamPackets:inInputData numberOfBytes:inNumberBytes numberOfPackets:inNumberPackets packetDescriptions:inPacketDescriptions];
    
}
@implementation CLAudioFileStream
@synthesize fileType = _fileType;
@synthesize readyToProducePackets = _readyToProducePackets;
@dynamic availabel;
@synthesize delegate = _delegate;
@synthesize duration = _duration;
@synthesize bitRate = _bitRate;
@synthesize fromat = _fromat;
@synthesize maxPacketSize = _maxPacketSize;
@synthesize audioDataByteCount = _audioDataByteCount;

- (instancetype)initWithFileType:(AudioFileTypeID)fileType fileSize:(unsigned long long)fileSize error:(NSError *__autoreleasing *)erro {
    self = [super init];
    if (self) {
        _discontinous = NO;
        _fileType = fileType;
        _fileSize = fileSize;
        [self _openAudioFileStreamWithFileTypeHint:_fileType error:erro];
    }
    return self;
}
- (void)_errorForStatus:(OSStatus)status error:(NSError **)error {
    if (status != noErr && error != NULL) {
        char errorString[20]={};
        *(UInt32 *)(errorString+1)=CFSwapInt32HostToBig(status);
        if (isprint(errorString[1])&&isprint(errorString[2])&&isprint(errorString[3])&&isprint(errorString[4])) {
            errorString[0]=errorString[5]='\'';
            errorString[6]='\0';
            printf("%s",errorString);
        }else{
            sprintf(errorString, "%d",(int)error);
        }
        *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
    }
}

#pragma mark - open & colse
- (BOOL)_openAudioFileStreamWithFileTypeHint:(AudioFileTypeID)fileTypeHint error:(NSError **)error {
    OSStatus status = AudioFileStreamOpen((__bridge void *)self, CLAudioFileStreamPropertyListener, CLAudioFileStreamPacketsCallback, fileTypeHint, &_audioFileStreamID);
    if (status != noErr) {
        _audioFileStreamID = NULL;
    }
    [self _errorForStatus:status error:error];
    return status == normal;
}
- (void)_close {
    [self _closeAudioFileStream];
}
- (void)_closeAudioFileStream {
    if (self.availabel) {
        AudioFileStreamClose(_audioFileStreamID);
        _audioFileStreamID = NULL;
    }
}
- (BOOL)availabel {
    return _audioFileStreamID != NULL;
}
#pragma mark - publice method
- (NSData *)fetchMagicCookie {
    UInt32 cookieSize;
    Boolean writeabel;
    OSStatus staus = AudioFileStreamGetPropertyInfo(_audioFileStreamID, kAudioFileStreamProperty_MagicCookieData, &cookieSize, &writeabel);
    if (staus != noErr) {
        return nil;
    }
    void *cookieData = malloc(cookieSize);
    staus = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_MagicCookieData, &cookieSize, cookieData);
    if (staus != noErr) {
        return nil;
    }
    NSData *cookie = [NSData dataWithBytes:cookieData length:cookieSize];
    free(cookieData);
    return cookie;
}
- (BOOL)paraseData:(NSData *)data error:(NSError *__autoreleasing *)error {
    
    if (self.readyToProducePackets && _packetDuration == 0) {
        [self _errorForStatus:-1 error:error];
        return NO;
    }
    OSStatus status = AudioFileStreamParseBytes(_audioFileStreamID, (UInt32)[data length], [data bytes], _discontinous?kAudioFileStreamParseFlag_Discontinuity:0);
    [self _errorForStatus:status error:error];
    return status == noErr;
}
- (void)close {
    [self close];
}
- (SInt64)seekToTime:(NSTimeInterval *)time {
    SInt64 approximateSeekOffset = _dataOffset + (*time/_duration) * _audioDataByteCount;
    SInt64 seekToPacket = floor(*time/_packetDuration);
    SInt64 seekByteOffset;
    UInt32 ioFlags = 0;
    SInt64 outDataByteOffset;
    OSStatus status = AudioFileStreamSeek(_audioFileStreamID, seekToPacket, &outDataByteOffset, &ioFlags);
    if (status == noErr && !(ioFlags * kAudioFileStreamSeekFlag_OffsetIsEstimated)) {
        *time -= ((approximateSeekOffset - _dataOffset)-outDataByteOffset)*8.0/_bitRate;
        seekByteOffset = outDataByteOffset + _dataOffset;
    } else {
        _discontinous = YES;
        seekByteOffset = approximateSeekOffset;
    }
    return seekByteOffset;
}
#pragma mark - callbacks
- (void)calculateBitRate {
    if (_packetDuration && _processdPacketsCount > BitRateEstimationMinPackets && _processdPacketsCount < BitRateEstimationMaxPackets) {
        double averagePacketByteSize = _processedPacketsSizeTotal/_processdPacketsCount;
        _bitRate = 8.0 * averagePacketByteSize / _packetDuration;
    }
}
- (void)calculateDuration {
    if (_fileSize > 0 && _bitRate > 0) {
        _duration = ((_fileSize -_dataOffset) * 8.0)/_bitRate;
    }
}
- (void)calculatePacketDuration {
    if (_fromat.mSampleRate > 0) {
        _packetDuration = _fromat.mFramesPerPacket/_fromat.mSampleRate;
    }
}
- (void)handleAudiFileStreamProperty:(AudioFileStreamPropertyID)propertyID {
    if (propertyID == kAudioFileStreamProperty_ReadyToProducePackets) {
        _readyToProducePackets = YES;
        _discontinous = YES;
        UInt32 sizeOfUInt32 = sizeof(_maxPacketSize);
        OSStatus status = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_PacketSizeUpperBound, &sizeOfUInt32, &_maxPacketSize);
        if (status != noErr || _maxPacketSize == 0) {
            status = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_MaximumPacketSize, &sizeOfUInt32, &_maxPacketSize);
        }
        if (_delegate && [_delegate respondsToSelector:@selector(audioFileStreamReadyToProducePackets:)]) {
            [_delegate audioFileStreamReadyToProducePackets:self];
        }
    } else if (propertyID == kAudioFileStreamProperty_DataOffset) {
        UInt32 offsetSize = sizeof(_dataOffset);
        AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_DataOffset, &offsetSize, &_dataOffset);
        _audioDataByteCount = _fileSize - _dataOffset;
        [self calculateDuration];
    } else if (propertyID == kAudioFileStreamProperty_DataFormat) {
        NSLog(@"get format");
        UInt32 asbSize = sizeof(_fromat);
        AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_DataFormat, &asbSize, &_fromat);
        [self calculatePacketDuration];
    } else if (propertyID == kAudioFileStreamProperty_FormatList) {
        NSLog(@"get format list");
        Boolean outWriteable;
        UInt32 formatListSize;
        OSStatus status = AudioFileStreamGetPropertyInfo(_audioFileStreamID, kAudioFileStreamProperty_FormatList, &formatListSize, &outWriteable);
        if (status == noErr) {
            AudioFormatListItem *formatList = malloc(formatListSize);
            OSStatus status = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_FormatList, &formatListSize, formatList);
            if (status == noErr) {
                UInt32 supportedFormatsSize;
                status = AudioFormatGetPropertyInfo(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &supportedFormatsSize);
                if (status != noErr) {
                    free(formatList);
                    return;
                }
                UInt32 suppoertedFormatCount = supportedFormatsSize/sizeof(OSType);
                OSType *suppoertedFormats = (OSType *)malloc(supportedFormatsSize);
                status = AudioFormatGetProperty(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &supportedFormatsSize, suppoertedFormats);
                if (status != noErr) {
                    free(formatList);
                    free(suppoertedFormats);
                    return;
                }
                for (int i = 0; i * sizeof(AudioFormatListItem) < formatListSize; i++) {
                    AudioStreamBasicDescription fromat = formatList[i].mASBD;
                    for (uint32_t j =0; j < suppoertedFormatCount; i++) {
                        if (fromat.mFormatID == suppoertedFormats[j]) {
                            _fromat = fromat;
                            [self calculatePacketDuration];
                            break;
                        }
                    }
                }
                free(suppoertedFormats);
            }
            free(formatList);
        }
    }
}
- (void)handleAudioFileStreamPackets:(const void *)packets numberOfBytes:(UInt32)numberOfBytes numberOfPackets:(UInt32)numberOfPackets packetDescriptions:(AudioStreamPacketDescription *)packetDescription {
    if (_discontinous) {
        _discontinous = NO;
    }
    if (numberOfBytes == 0 || numberOfPackets == 0) {
        return;
    }
    BOOL deletePackDesc = NO;
    if (packetDescription == NULL) {
        deletePackDesc = YES;
        UInt32 packetSize = numberOfBytes/numberOfPackets;
        AudioStreamPacketDescription *description = (AudioStreamPacketDescription *)malloc(sizeof(AudioStreamPacketDescription) * numberOfPackets);
        for (int i = 0; i < numberOfPackets; i++) {
            UInt32 packetOffset = packetSize*i;
            description[i].mStartOffset = packetOffset;
            description[i].mVariableFramesInPacket = 0;
            if (i == numberOfPackets-1) {
                description[i].mDataByteSize = numberOfBytes - packetOffset;
            } else {
                description[i].mDataByteSize = packetSize;
            }
        }
        packetDescription = description;
    }
    NSMutableArray *paraseDataArray = [[NSMutableArray alloc] init];
    for (int i = 0; i < numberOfPackets; i++) {
        SInt64 packetOffset = packetDescription[i].mStartOffset;
        CLParsedAudioData *parsedData = [CLParsedAudioData parasedAudioDataWithBytes:packets + packetOffset packetDescription:packetDescription[i]];
        [paraseDataArray addObject:parsedData];
        if (_processdPacketsCount < BitRateEstimationMaxPackets) {
            _processedPacketsSizeTotal += parsedData.packetDescription.mDataByteSize;
            _processdPacketsCount += 1;
            [self calculateBitRate];
            [self calculateDuration];
        }
    }
    [_delegate audioFileStream:self audioDataParsed:paraseDataArray];
    if (deletePackDesc) {
        free(packetDescription);
    }
}
@end
