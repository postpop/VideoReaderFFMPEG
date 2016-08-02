% test equivalence of VIDEOREADER and VIDEOREADERFFMPEG
% in terms of meta data and frame data
% not the nonlinear relation of pixel values - seems as if matlab and
% ffmpeg have different LUTs for that...
clear all;
clc, clf
colormap('gray')
%% 0. init VIDEOREADER objects
videoFileName = '140731_1422.mp4';
vr{2} = VideoReaderFFMPEG(videoFileName);
%% 1. make sure metadata are identical
PropertyNames = {'NumberOfFrames','FrameRate','Width','Height'};
disp([class(vr{2})])
for prop = 1:length(PropertyNames)
   disp([vr{2}.(PropertyNames{prop})]);
end
%% 2. load frames using the built-in VIDEOREADER
framesToRead = round(linspace(10, vr{2}.NumberOfFrames-10,10));
toHit = {'1559806.5309';'1563957.9531';'1564038.2235';'1561726.0661';'1559567.2733';'1558649.0342';'1560885.5080';'1562654.8600';'1560345.1193';'1562141.9925'};

for fr = 1:length(framesToRead)
   % read and plot frames
   frame = double(vr{2}.read(framesToRead(fr)));
   checkSum(fr) = mean(mean(frame(:,:,1) + frame(:,:,2)*100 + frame(:,:,3)*10000));
   checkSumStrg{fr} = sprintf('%8.4f',checkSum(fr));
   disp([checkSumStrg{fr} ' ?=? ' toHit{fr}])
   disp(strcmp(checkSumStrg{fr}, toHit{fr}))
end
%% test DELETE function
disp('test delete function:')
disp(' PRE:' )
dir('*.tif')
vr = [];
disp(' POST:' )
dir('*.tif')

