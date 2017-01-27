# VideoReaderFFMPEG
Matlab wrapper for FFMPEG that implements a VideoReader-like interface.

## Documentation
- Constructor: `vr = VideoReaderFFMPEG('test.mp4');`
- Additional arguments (optional): 
    - `tempFolder` - path to save the temporary image files to (optional, defaults to `./`)
    - `FFMPEGpath` - path to the `ffmpeg` and `ffprobe` binaries (optional, defaults to `/usr/local/bin` on osx/unix and `C:\Program Files\ffmpeg\bin` on windows)
    - `imageFormat` - image file format used to temporarily store frames (optional, defauts to `tif`)
- Properties: `Width`, `Height`, `NumberOfFrames`, `FrameRate`, `Channels`
- Methods: 
    - `read()` with single frames or a range of frames `[startFrame endFrame]`, e.g. `vr.read([100 200])` reads frames 100 to 200, returns them as `[WIDTH x HEIGHT x CHANNELS x NFRAMES]` matrix
    - `clean()` deletes all temporary image files (automatically called upon object deletion)

## Usage
```matlab
vr = VideoReaderFFMPEG('test.mp4')  % open video file
frame10 = vr.read(10)               % read frame 10
frames100to200 = vr.read([100 200]) % read frames 100 to 200
vr.clean()                          % delete temporary image files after your done

```

## Internals
- uses `ffprobe` to get meta data
- uses `ffmpeg` to export video frames as images which are loaded using matlab's `imread()`
- tested using `ffmpeg` v2.5 and v2.6

   
