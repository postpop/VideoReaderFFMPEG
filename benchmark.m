% benchmark frame reads:
% compares builtin VIDEOREADER and unbuffered/buffered FFMPEG

clear all; clc, clf
colormap('gray')

videoFileName = '140731_1422.mp4';
frameNumber = 1000;
frameStart = 1000;
tt = zeros(frameNumber, 3);
%% 1. builtin VIDEOREADER
clear vr
vr = VideoReader(videoFileName);

for f = 1:frameNumber
   tic
   vr.read(frameStart+f);
   tt(f,1) = toc;
end
%% 2.  unbuffered FFMPEG
clear vr
vr = VideoReaderFFMPEG(videoFileName);
vr.buffered = false;

for f = 1:frameNumber
   tic
   vr.read(frameStart*2+f);
   tt(f,2) = toc;
end
%% 3. buffered FFMPEG
clear vr
vr = VideoReaderFFMPEG(videoFileName);
vr.buffered = true;
vr.bufferSize = 10;% larger bufferSizes don't help on my system

for f = 1:frameNumber
   tic
   vr.read(frameStart*3+f);
   tt(f,3) = toc;
end
%% plot results
subplot(1,4,1:3)
plot(1000*tt)
xlabel('frame number')
ylabel('read time per frame [ms]')
legend({'builtin','ffmpeg','buffered ffmpeg'})

subplot(1,4,4)
bar(mean(tt)*1000)
ylabel('avg. read time [ms]')
set(gca, 'XTickLabel', {'builtin','ffmpeg','buffered ffmpeg'})

saveas(gcf, 'benchmark.pdf', 'pdf')

fprintf('average read times per frame:\n')
fprintf('builtin: %d ms , ffmpeg %d ms, buffered ffmpeg %f ms\n', round(1000*mean(tt)))

