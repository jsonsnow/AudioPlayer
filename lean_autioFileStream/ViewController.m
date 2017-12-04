//
//  ViewController.m
//  lean_autioFileStream
//
//  Created by chen liang on 2017/10/29.
//  Copyright © 2017年 chen liang. All rights reserved.
//

#import "ViewController.h"
#import "CLSimpleAudioPlayer.h"
@interface ViewController ()
{
    CLSimpleAudioPlayer *_player;
}
@end
@implementation ViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    NSString *path = [[NSBundle mainBundle] pathForResource:@"MP3Sample" ofType:@"mp3"];
    CLSimpleAudioPlayer *palyer = [[CLSimpleAudioPlayer alloc] initWithFilePath:path fileType:kAudioFileMP3Type];
    _player = palyer;
    [_player play];
    // Do any azdditional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
