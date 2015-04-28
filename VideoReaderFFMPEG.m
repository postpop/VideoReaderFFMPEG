classdef VideoReaderFFMPEG < handle
   % For reading videos - needed it since the builting VIDEOREADER wouldn't
   % accept h264 encoded files - this is a simple command line wrapper for FFMPEG
   %
   % side-note: 2-2.5x faster on an SSD drive than the builtin VIDEOREADER
   %
   % Exposes a simple interface that implements a subset of the builtin
   %  CONSTRUCTOR:
   %     vr = VideoReaderFFMPEG(fileName, ['tempFolder', tempFolder, 'FFMPEGPath', FFMPEGPath]);
   %     PARAMS:
   %        fileName    - ...
   %        tempFolder  - OPTIONAL - location to store temporary files, defaults to './'
   %        FFMPEGPath  - OPTIONAL - location of FFMPEG/FFPROBE executables defaults to '/usr/local/bin' (UNIX) or 'C:\Program Files\ffmpeg\bin' (WIN)
   %
   %  METHODS:
   %     read(frames) - with single frames or a range of frames [startFrame endFrame]
   %     clean()      - NOT IMPLEMENTED - delete all temporary files
   %
   %  PROPERTIES:
   %     Width, Height, NumberOfFrames, FrameRate, Channels
   %
   %  see also VIDEOREADER
   
   % JC - created 2015/04/03
   
   % TODO
   % - generate random basename instead of 'tmp' to avoid collisions of
   %   readers simultaneously working in the same folder/on the same file
   
   properties
      % input parameters:
      vFileName
      tempFolder
      FFMPEGPath
      % metadata:
      NumberOfFrames
      FrameRate
      Width, Height
      Channels
      % buffer params:
      buffered
      bufferSize
      bufferedFrameTimes
      tempName                % name for temporary tiff files - to avoid buffer collision if multiple instances of VideoReaderFFMPEG access the same tempFolder
      % unused - delete?
      vr
   end
   
   methods (Access='public')
      function obj = VideoReaderFFMPEG(vFileName, varargin)
         
         % parse input arguments
         p = inputParser;
         addRequired(p,'vFileName', @ischar);
         defaultTempFolder = '.';
         addParamValue(p, 'tempFolder', defaultTempFolder, @ischar);%#ok<*NVREPL> % should be addParameter - used the old name for compatibility with 2013a
         if isunix
            defaultFFMPEGPath = '/usr/local/bin';
         end
         if ispc
            defaultFFMPEGPath = 'C:\Program Files\ffmpeg\bin';
         end
         addParamValue(p, 'FFMPEGPath', defaultFFMPEGPath, @ischar);% should be addParameter - used the old name for compatibility with 2013a
         parse(p,vFileName,varargin{:})
         
         if ~exist(p.Results.vFileName,'file')% this should be part of the inputParser
            error('video file %s does not exist.', p.Results.vFileName);
         else
            obj.vFileName = p.Results.vFileName;
         end
         obj.tempFolder = p.Results.tempFolder;
         obj.FFMPEGPath= p.Results.FFMPEGPath;
         
         obj.tempName = tempname(obj.tempFolder);
         
         % add location of FFMPEG/FFPROBE to path
         path = getenv('PATH');
         if isunix
            path = [path ':' obj.FFMPEGPath];% this is where FFPROBE is installed to on my system
         end
         if ispc % WINDOWS
            path = [path ';' obj.FFMPEGPath ';'];%
         end
         setenv('PATH', path);
         % check that FFMPEG and FFPROBE are available in path
         % TO FIX: system('..') should return 0 if it exists but returns 1, and the statement prints the result
         %assert(system('ffmpeg')<=1, 'FFMPEG not found!  Use FFMPEGPath parameter to point to binary');
         %assert(system('ffprobe')<=1, 'FFPROBE not found! Use FFMPEGPath parameter to point to binary');
         
         % get metadata - TODO put into its own private/public(?) function
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
         
         evalc(['!ffmpeg -y -ss ' num2str(frameTime, '%1.8f') ' -i ' obj.vFileName ' -v error -vframes 1 ' obj.tempName '.tif']);
         frame = imread([obj.tempName, '.tif']);
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
            evalc(['!ffmpeg -y -ss ' num2str(frameTime, '%1.8f') ' -i ' obj.vFileName ' -v error -vframes ' int2str(obj.bufferSize) ' ' obj.tempName '%5d.tif']);
            bufferHits = ismember(obj.bufferedFrameTimes, frameTime);
         end
         tifFileName = sprintf([obj.tempName, '%05d.tif'], find(bufferHits,1,'first'));
         frame = imread(tifFileName);
         %          delete(tifFileName)
      end
   end
end