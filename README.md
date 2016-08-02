# VideoReaderFFMPEG
Matlab wrapper for FFMPEG that implements a VideoReader-like interface.

## Documentation
- Constructor: `vr = VideoReaderFFMPEG('test.mp4');`
- Additional arguments (optional): 
    - `tempFolder` - path to save the temporary image files to (defaults to `./`)
    - `FFMPEGpath` - path to the `ffmpeg` and `ffprobe` binaries (defaults to `/usr/local/bin` on osx/unix and `C:\Program Files\ffmpeg\bin` on windows)
    - `imageFormat` - image file format used to temporarily store frames (defauts to `tif`)
- Properties: `Width`, `Height`, `NumberOfFrames`, `FrameRate`, `Channels`
- Methods: `read()` with single frames or a range of frames `[startFrame endFrame]`, e.g. `vr.read([100 200])` reads frames 100 to 200

## Internals
- uses `ffprobe` to get meta data
- uses `ffmpeg` to export video frames as TIF which are loaded using matlab's `imread()`
- tested using `ffmpeg` v2.5 and v2.6

   
