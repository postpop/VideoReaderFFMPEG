classdef VideoReaderFFMPEG < handle
   % For reading videos - needed it since the builtin VIDEOREADER wouldn't
   % accept h264 encoded files - this is a simple command line wrapper for FFMPEG.
   % Exposes a simple interface that implements a subset of the builtin
   %
   %  CONSTRUCTOR:
   %     vr = VideoReaderFFMPEG(fileName, 'tempFolder', tempFolder, 'FFMPEGPath', FFMPEGPath, 'imageFormat', imageFormat, 'verbose', verbose);
   %
   %     PARAMS:
   %        fileName    - path to video file
   %        tempFolder  - OPTIONAL - location to store temporary files, defaults to './'
   %        FFMPEGPath  - OPTIONAL - location of FFMPEG/FFPROBE executables,
   %                                 defaults to '/usr/local/bin' (OSX/UNIX) or 'C:\Program Files\ffmpeg\bin' (WIN)
   %        imageFormat - OPTIONAL - format used as a temporary frame store, defaults to 'tif'
   %        verbose     - OPTIONAL - display ffmpeg output messages, defaults to false (not output)
   %
   %  METHODS:
   %     read(frames) - single frames or a range of frames [startFrame endFrame],
   %                    returns frames as a [WIDTH x HEIGHT x CHANNELS x NFRAMES] matrix
   %     clean()      - delete all temporary files
   %
   %  PROPERTIES:
   %     Width, Height, NumberOfFrames, FrameRate, Channels
   %     tempName, tempFolder, imageFormat
   %     buffered, bufferSize, bufferedFrameTimes, 
   %
   %  see also VIDEOREADER
   
   % JC - created 2015/04/03
   
   % TODO:
   % implement using pipes:
   %  https://www.mathworks.com/matlabcentral/fileexchange/13851-popen-read-and-write
   %  http://ffmpy.readthedocs.io/en/latest/examples.html#using-pipe-protocol
      
   properties
      % input parameters:
      vFileName
      tempFolder
      FFMPEGPath
      imageFormat
      verbose
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
      % unused - delete or keep for compatibility?
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
         addParamValue(p, 'imageFormat','tif', @ischar);% should be addParameter - used the old name for compatibility with 2013a
         addParamValue(p, 'verbose',false);% should be addParameter - used the old name for compatibility with 2013a
         parse(p,vFileName,varargin{:})
         
         % ensure that video file exists
         if ~exist(p.Results.vFileName,'file')% this should be part of the inputParser
            error('video file %s does not exist.', p.Results.vFileName);
         else
            obj.vFileName = p.Results.vFileName;
         end
         
         % ensure that imageformat parameter is a valid image format
         imformatsTable = imformats();
         validFormats = [imformatsTable.ext];
         validatestring(p.Results.imageFormat,validFormats, 'VideoReaderFFMPEG','imageFormat');
         obj.imageFormat = p.Results.imageFormat;
         
         % should check for existence of those, too
         obj.tempFolder = p.Results.tempFolder;
         obj.FFMPEGPath= p.Results.FFMPEGPath;
         
         obj.tempName = tempname(obj.tempFolder);
         
         obj.verbose = p.Results.verbose;
         %% add location of FFMPEG/FFPROBE to path
         syspath = getenv('PATH');
         if isempty(strfind(syspath, obj.FFMPEGPath))
            if isunix
               syspath = [syspath ':' obj.FFMPEGPath];% this is where FFPROBE is installed to on my system
            end
            if ispc % WINDOWS
               syspath = [syspath ';' obj.FFMPEGPath ';'];%
            end
         end
         setenv('PATH', syspath);
         %% check that FFMPEG and FFPROBE are available in path
         % TO FIX: system('..') should return 0 if it exists but returns 1, and the statement prints the result
         %assert(system('ffmpeg')<=1, 'FFMPEG not found!  Use FFMPEGPath parameter to point to binary');
         %assert(system('ffprobe')<=1, 'FFPROBE not found! Use FFMPEGPath parameter to point to binary');
         
         obj.getMetaData()
         
         % parameters for buffered reading
         obj.buffered = false;
         obj.bufferedFrameTimes = [];
         obj.bufferSize = 10;
      end
      
      function frame = read(obj, frameNumber)
         % frame  = read(frameNumber);
         % frames = read([startFrameNumner endFrameNumber]);
         % returns frames as a [WIDTH x HEIGHT x CHANNELS x NFRAMES] matrix
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
            frameTimes = frameNumber(1)/obj.FrameRate:1/obj.FrameRate:frameNumber(2)/obj.FrameRate;
            frame = zeros(obj.Height,obj.Width,obj.Channels,length(frameTimes),'uint8');
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
         % delete temporary images from disk
         if ~isempty(dir([obj.tempName '.' obj.imageFormat]))
            delete([obj.tempName '.' obj.imageFormat]);
         end
         if ~isempty(dir([obj.tempName '*.' obj.imageFormat]))
            delete([obj.tempName '*.' obj.imageFormat]);
         end
      end
      
      function delete(obj)
         % delete temporary images from disk when deleting the object
         obj.clean()
      end
      
   end
   
   methods (Access='private')
      function getMetaData(obj)
         % get metadata using FFPROBE
         out = evalc(['!ffprobe -show_streams ' obj.vFileName]);
         out(strfind(out, '=')) = [];
         % map FFPROBE output to their corresponding class variables
         keys = {'nb_frames', 'width', 'height', 'r_frame_rate'};
         keysField = {'NumberOfFrames', 'Width', 'Height', 'FrameRate'};
         for idx = 1:length(keys)
            key = keys{idx};
            Index = strfind(out, key);
            obj.(keysField{idx}) = sscanf(out(Index(1) + length(key):end), '%g', 1);
         end
         % number of color channels parsed from frame since it's not exposed through FFPROBE
         obj.Channels = size(obj.read(1),3); 
      end
      
      function frame = readSingleFrame(obj, frameTime)
         % write frame to file using FFMPEG - frames are accessed based
         % on time starting with 0 (so frame #1 is 0, not 1/fps!!).
         
         % FFMPEG parameters used:
         % -vframes 1   - number of frames to extract
         % -ss seconds  - start point
         % -v error     - print only error messages
         % -y           - say 'YES' to any prompt
         outMessage = evalc(['!ffmpeg -y -ss ' num2str(frameTime, '%1.8f') ' -i ' obj.vFileName ' -vframes 1 ' obj.tempName '.' obj.imageFormat]);
%          outMessage = evalc(['!ffmpeg -y -ss ' num2str(frameTime, '%1.8f') ' -i ' obj.vFileName ' -v error -vframes 1 ' obj.tempName '.' obj.imageFormat]);
         if obj.verbose
            disp(outMessage)
         end
         frame = imread([obj.tempName '.' obj.imageFormat]);
      end
      
      function frame = readSingleFrameBuffered(obj, frameTime)
         % write frame to file using FFMPEG - frames are accessed based
         % on time starting with 0 (so frame #1 is 0, not 1/fps!!).
         % uses tif files buffered on disk
         
         % FFMPEG parameters used:
         % -vframes 1   - number of frames to extract
         % -ss seconds  - start point
         % -v error     - print only error messages
         % -y           - say 'YES' to any prompt
         
         bufferHits = ismember(obj.bufferedFrameTimes, frameTime);
         if ~any(bufferHits)
            obj.bufferedFrameTimes = frameTime + (0:obj.bufferSize-1)/obj.FrameRate;
%             outMessage = evalc(['!ffmpeg -y -ss ' num2str(frameTime, '%1.8f') ' -i ' obj.vFileName ' -v error -vframes ' int2str(obj.bufferSize) ' ' obj.tempName '%05d.' obj.imageFormat]);
            outMessage = evalc(['!ffmpeg -y -ss ' num2str(frameTime, '%1.8f') ' -i ' obj.vFileName ' -vframes ' int2str(obj.bufferSize) ' ' obj.tempName '%05d.' obj.imageFormat]);
            if obj.verbose
               disp(outMessage)
            end
            bufferHits = ismember(obj.bufferedFrameTimes, frameTime);
         end
         imageFileName = sprintf([obj.tempName '%05d.' obj.imageFormat], find(bufferHits,1,'first'));
         frame = imread(imageFileName);
      end
   end
end