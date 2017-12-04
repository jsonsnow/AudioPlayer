//
//  CLParsedAudioData.h
//  lean_autioFileStream
//
//  Created by chen liang on 2017/10/29.
//  Copyright © 2017年 chen liang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudioTypes.h>

@interface CLParsedAudioData : NSObject
@property (nonatomic, readonly) NSData *data;
@property (nonatomic, readonly) AudioStreamPacketDescription packetDescription;

+ (instancetype)parasedAudioDataWithBytes:(const void *)bytes packetDescription:(AudioStreamPacketDescription)pacektDescription;
@end
