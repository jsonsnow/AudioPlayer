### 音频
#### 基础
音频文件的生成过程是将声音信息采样、量化和编码产生的数字信息过程，人耳能听到的声音，最低的频率是从20HZ起一直到最高的频率20KHZ,因此音频文件格式的最大带宽是20KHZ。根据奈克斯特理论，只有采样频率高于声音信号最高频率的两倍时，才能把数字信号表示的声音还原成为原来的声音，因此音频文件的采样率一般在40-50KHZ，比如常见的CD音频采样率44.1KHZ。

对声音进行采样、量化过程被称为脉冲编码调制(Pulse Code Modulation),简称PCM，PCM数据是最原始的音频数据完全无损但体积庞大，为了解决这个问题先后诞生了一系列音频格式，这些音频格式运用不同的方法对音频数据进行压缩，其中有无损压缩(ALAC、APE、FLAC)和有损压缩（MP3、ACC、OGG、WMA）两种

目前最常用的是MP3,它舍弃PCM音频数据中人类听觉不敏感的部分。MP3格式中码率(BitRate)代表了MP3数据的压缩质量，现在常用的码率有128kbit/s, 160kbit/s, 320kbit/s等等，这个值越高声音质量也就越高。MP3编码方式常用的有两种固定码率(Constant bitrate, CBR)和可变码率(Variable bitrate, CBR)


MP3格式中的数据通常由两部分组成，一部分为ID3用来存储歌名、演唱者、专辑、音轨等信息，另一部分为音频数据。音频数据以帧(frame)为单位存储，每个音频都有自己的帧头，如下图所示。MP3中的每一个帧都有自己的帧头，其中存储了采样率等解码必须得信息，所以每一个帧都可以独立于文静存在和播放，帧头之后存储音频数据，这些音频数据是若干PCM数据帧经过压缩算法压缩得到，对CBR的MP3数据来说每个帧包含的PCM数据帧是固定的，而VBR是可变的。

![avatar](http://msching.github.io/images/iOS-audio/mp3frame.jpg)


### iOS音频播放概述
* 1.读取MP3文件
* 2.解析采样率、码率、时长等信息、分离MP3中的音频帧
* 3.对分离出来的音频帧解码得到PCM数据
* 4.对PCM数据进行音效处理(均衡器、混响器、非必须)
* 5.把PCM数据解码成音频信号
* 6.把音频信息交给硬件播放
* 7.重复1-6步直到播放完成


在iOS系统中apple对上述的流程进行了封装并提供了不同层次的接口

![avatar](http://msching.github.io/images/iOS-audio/api-architectural-layers.png)

以中高层接口为例：

* Audio File Services: 读写音频数据，可以完成播放流程中的第2步；
* Audio File Stream Services: 对音频进行解码，可以完成播放流程中的第2步；
* Audio Converter Services：音频数据转换，可以完成播放流程中的第三部；
* Audio Processing Graph Services：音效处理模块，可以完成播放流程中的第4步
* Audio Unit Services: 播放音频数据：可以完成播放流程中的第5步、第5步
* Extened Audio File Service: Audio File services和Audio Converter services的结合体；
* AVAudioPlayer/AVPlayer(AVFoundation)：高级接口，可以完成整个音频播放过程；
* Audio Queue Services: 高级接口，可以进行录音和播放，可以完成播放流程中的第3，5，6步
* OpenAL: 用于游戏音频播放

Audio File Service（Audio File Stream Servies）分离音频帧， Audio Queue Services 解码播放音频信息。

### AudioSession简介
AudioSession主要包含以下功能

* 1.确定你的app如何使用音频(是播放还是录音)
* 2.为你的app选择合适的输入输出设备(比如输入用的麦克风，输出是耳机，手机攻防或者airplay)
* 3.协调你的app的音频播放和系统以及其他app行为(例如有电话时需要打断，电话结束时需要恢复，按下静音按钮时是否歌曲也静音等)



