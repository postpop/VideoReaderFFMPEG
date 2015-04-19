% test equivalence of VIDEOREADER and VIDEOREADERFFMPEG
% in terms of meta data and frame data
% not the nonlinear relation of pixel values - seems as if matlab and
% ffmpeg have different LUTs for that...
clear all, clc, clf
colormap('gray')
%% 0. init VIDEOREADER objects
videoFileName = '140731_1422.mp4';
vr{1} = VideoReader(videoFileName);
vr{2} = VideoReaderFFMPEG(videoFileName);
vr{2}.buffered = true;
%% 1. make sure metadata are identical
PropertyNames = {'NumberOfFrames','FrameRate','Width','Height'};
disp([class(vr{1}) ' ' class(vr{2})])
for prop = 1:length(PropertyNames)
   disp([vr{1}.(PropertyNames{prop}), vr{2}.(PropertyNames{prop})]);
end
%% 2. load frames using the built-in VIDEOREADER
framesToRead = 1000:1010;%round(linspace(10, vr{1}.NumberOfFrames-10,10));
for fr = 1:length(framesToRead)
   % read and plot frames
   for vid = 1:length(vr)
      subplot(3,length(framesToRead), (vid-1)*length(framesToRead)+fr)
      if vid==2
         frame{vid} = permute(vr{vid}.read(framesToRead(fr)),[2 1 3]);
      else
         frame{vid} = vr{vid}.read(framesToRead(fr));
      end
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
