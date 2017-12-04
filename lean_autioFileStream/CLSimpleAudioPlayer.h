//
//  CLSimpleAudioPlayer.h
//  lean_autioFileStream
//
//  Created by chen liang on 2017/11/12.
//  Copyright © 2017年 chen liang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
typedef NS_ENUM(NSUInteger,CLSAPStatus) {
    CLSAPStatusStopped = 0,
    CLSAPStatusPalying = 1,
    CLSAPStatusWaiting = 2,
    CLSAPStatusPaused = 3,
    CLSAPStatusFlushing = 4,
};

@interface CLSimpleAudioPlayer : NSObject
@property (nonatomic, copy, readonly) NSString *filePath;
@property (nonatomic, assign, readonly) AudioFileTypeID fileType;

@property (nonatomic, readonly) CLSAPStatus status;
@property (nonatomic, readonly) BOOL isPlayingOrWaiting;
@property (nonatomic, assign, readonly) BOOL failed;
@property (nonatomic, assign) NSTimeInterval progress;
@property (nonatomic, readonly) NSTimeInterval duration;

- (instancetype)initWithFilePath:(NSString *)filePath fileType:(AudioFileTypeID)fileType;

- (void)play;
- (void)pause;
- (void)stop;
@end
