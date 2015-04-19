classdef VideoReaderFFMPEG < handle
   % For reading videos - needed it since the builting VIDEOREADER wouldn't
   % accept h264 encoded files - this is a simple command line wrapper for FFMPEG
   %
   % side-note: 2-2.5x faster than builtin VIDEOREADER
   %
   % Exposes a simple interface that implements a subset of the builtin
   %  CONSTRUCTOR:
   %     vr = VideoReaderFFMPEG('test.mp4');
   %
   %  METHODS:
   %     read() with single frames or a range of frames [startFrame endFrame]
   %
   %  PROPERTIES:
   %     Width, Height, NumberOfFrames, FrameRate, Channels
   %
   
   % JC - created 2015/04/03
   
   properties
      vr
      vFileName
      NumberOfFrames
      FrameRate
      Width, Height
      Channels
      bufferedFrameTimes
      buffered
      bufferSize
   end
   
   methods (Access='public')
      function obj = VideoReaderFFMPEG(vFileName)
         if ~exist(vFileName,'file')
            error('video file %s does not exist.', vFileName);
         end
         obj.vFileName = vFileName;
         % add location of FFMPEG/FFPROBE to path
         path1 = getenv('PATH');
         path1 = [path1 ':/usr/local/bin'];% this is where FFPROBE is installed to on my system
         setenv('PATH', path1);
         
         % get metadata
         out = evalc(['!ffprobe -show_streams ' obj.vFileName]);
         out(strfind(out, '=')) = [];
         keys = {'nb_frames', 'width', 'height', 'r_frame_rate'};
         keysField = {'NumberOfFrames', 'Width', 'Height', 'FrameRate'};
         for idx = 1:length(keys);
            key = keys{idx};
            Index = strfind(out, key);
            obj.(keysField{idx}) = sscanf(out(Index(1) + length(key):end), '%g', 1);
         end
         obj.Channels = size(obj.read(1),3);
         %
         obj.bufferedFrameTimes = [];
         obj.buffered = false;
         obj.bufferSize = 10;
      end
      
      function frame = read(obj, frameNumber)
         % frame = read(frameNumber);
         % frames = read([startFrameNumner endFrameNumber]);
         %
         % direct or buffered (experimental, set obj.buffered=true) reading of frames
         
         frameNumber = frameNumber - 1;% zero-based
         if length(frameNumber)==1
            frameTime = (frameNumber)./obj.FrameRate - 0.1/obj.FrameRate;
            if obj.buffered
               frame = obj.readSingleFrameBuffered(frameTime);
            else
               frame = obj.readSingleFrame(frameTime);
            end
            
            
            if length(size(frame))==2
               frame = reshape(frame, [size(frame),1,1]);
            end
         else
            frameTimes = linspace(frameNumber(1)./obj.FrameRate, 1./obj.FrameRate, frameNumber(2)./obj.FrameRate);
            frame = zeros(obj.Width,obj.Height,obj.Channels,length(frameTimes),'uint8');
            for f = 1:length(frameTimes)
               if obj.buffered
                  frame(:,:,:,f) = obj.readSingleFrameBuffered(frameTimes(f));
               else
                  frame(:,:,:,f) = obj.readSingleFrame(frameTimes(f));
               end
            end
         end
      end
      
      function clean(obj)
         % deletes temporary tifs from disk - make this safe so we don't
         % accidentally delete files
         
         % delete('tmp.tif')
      end
      
   end
   
   methods (Access='private')
      function frame = readSingleFrame(obj, frameTime)
         % write RAW frame to file using FFMPEG - frames are accessed based
         % on time starting with 0 (so frame #1 is 0, not 1/fps!!).
         
         % -vframes 1   - number of frames to extract
         % -ss seconds  - start point
         % -v error     - print only error messages
         % -y           - say 'YES' to any prompt
         
         evalc(['!ffmpeg -y -ss ' num2str(frameTime, '%1.8f') ' -i ' obj.vFileName ' -v error -vframes 1 tmp.tif']);
         frame = permute(imread('tmp.tif'), [2 1 3]);
         %          delete('tmp.tif')
      end
      
      function frame = readSingleFrameBuffered(obj, frameTime)
         % write RAW frame to file using FFMPEG - frames are accessed based
         % on time starting with 0 (so frame #1 is 0, not 1/fps!!).
         
         % -vframes 1   - number of frames to extract
         % -ss seconds  - start point
         % -v error     - print only error messages
         % -y           - say 'YES' to any prompt
         
         bufferHits = ismember(obj.bufferedFrameTimes, frameTime);
         if ~any(bufferHits)
            obj.bufferedFrameTimes = frameTime + (0:obj.bufferSize-1)/obj.FrameRate;
            evalc(['!ffmpeg -y -ss ' num2str(frameTime, '%1.8f') ' -i ' obj.vFileName ' -v error -vframes ' int2str(obj.bufferSize) ' tmp%5d.tif']);
            bufferHits = ismember(obj.bufferedFrameTimes, frameTime);
         end
         tifFileName = sprintf('tmp%05d.tif', find(bufferHits));
         frame = permute(imread(tifFileName), [2 1 3]);
         %          delete(tifFileName)
      end
   end
end