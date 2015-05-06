% test equivalence of VIDEOREADER and VIDEOREADERFFMPEG
% in terms of meta data and frame data
% not the nonlinear relation of pixel values - seems as if matlab and
% ffmpeg have different LUTs for that...
clear all;
clc, clf
colormap('gray')
%% 0. init VIDEOREADER objects
videoFileName = '140731_1422.mp4';
vr{1} = VideoReader(videoFileName);
vr{2} = VideoReaderFFMPEG(videoFileName);
%% 1. make sure metadata are identical
PropertyNames = {'NumberOfFrames','FrameRate','Width','Height'};
disp([class(vr{1}) ' ' class(vr{2})])
for prop = 1:length(PropertyNames)
   disp([vr{1}.(PropertyNames{prop}), vr{2}.(PropertyNames{prop})]);
end
%% 2. load frames using the built-in VIDEOREADER
framesToRead = round(linspace(10, vr{1}.NumberOfFrames-10,10));
clf
for fr = 1:length(framesToRead)
   % read and plot frames
   for vid = 1:length(vr)
      subplot(3,length(framesToRead), (vid-1)*length(framesToRead)+fr)
      frame{vid} = vr{vid}.read(framesToRead(fr));
      imagesc(frame{vid})
      axis('square','off')
   end
   % plot frame pixel values - should be straight (and slightly curved)
   % line)
   subplot(3,length(framesToRead), 2*length(framesToRead)+fr)
   plot(frame{1}(:), frame{2}(:), '.k')
   hold on
   plot([0 255],[0 255],'k')
   axis('tight','square')
   if fr==1
      xlabel('builtin')
      ylabel('FFMPEG')
   end
end
%% test DELETE function
disp('test delete function:')
disp(' PRE:' )
dir('*.tif')
vr = [];
disp(' POST:' )
dir('*.tif')

