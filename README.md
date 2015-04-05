# VideoReaderFFMPEG
Wrapper for FFMPEG that implements a VideoReader-like interface. 2-2.5x faster than builtin VideoReader.
   
Exposes a simple interface that implements a subset of the builtin VideoR
CONSTRUCTOR:
```matlab
    vr = VideoReaderFFMPEG('test.mp4');
```   
METHODS:
    `read()` with single frames or a range of frames `[startFrame endFrame]`   
PROPERTIES:
    `Width`, `Height`, `NumberOfFrames`, `FrameRate`, `Channels`
   