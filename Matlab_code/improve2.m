
clc;
clear;
close all;

%% 1. Load clean speech

filename = 'C:\MATLAB\speech enhancement project\matlab\input\test.wav';

[speech, Fs] = audioread(filename);

% Convert stereo to mono
if size(speech, 2) > 1
    speech = mean(speech, 2);
end

% Remove DC offset and normalize
speech = speech - mean(speech);
speech = speech / (max(abs(speech)) + eps);

N = length(speech);
duration = N / Fs;

fprintf('Sampling frequency: %d Hz\n', Fs);
fprintf('Speech duration: %.2f seconds\n', duration);

%% 2. Generate white Gaussian noise

rng(1);

inputSNR = 5;  % Desired input SNR in dB

speechPower = mean(speech.^2);
noisePower = speechPower / (10^(inputSNR/10));

% Generate noise for the noise-only segment and speech segment
noiseDuration = 0.5;
noiseSamples = round(noiseDuration * Fs);


% Generate pink noise
Lnoise = N + noiseSamples;

whiteNoise = randn(Lnoise, 1);
pinkNoise = filter(1, [1 -0.98], whiteNoise);

% Remove DC component
pinkNoise = pinkNoise - mean(pinkNoise);

% Normalize to the required noise power
pinkNoise = pinkNoise / (sqrt(mean(pinkNoise.^2)) + eps);
noise = pinkNoise * sqrt(noisePower);


% Noise-only segment followed by noisy speech
noiseOnly = noise(1:noiseSamples);
speechNoise = noise(noiseSamples+1:end);

noisySpeech = speech + speechNoise;

recording = [noiseOnly; noisySpeech];

fprintf('Noise type: White Gaussian noise\n');
fprintf('Target input SNR: %.2f dB\n', inputSNR);

%% 3. Frame the recording

frameLen = round(0.025 * Fs);  % 25 ms
hop = round(0.010 * Fs);       % 10 ms
nfft = 2^nextpow2(frameLen);

% Hann window
window = 0.5 - 0.5*cos(2*pi*(0:frameLen-1)'/frameLen);

L = length(recording);
nFrames = max(1, ceil((L-frameLen)/hop) + 1);
paddedLength = (nFrames-1)*hop + frameLen;

x = [recording; zeros(paddedLength-L,1)];
starts = 1 + (0:nFrames-1)*hop;

Y = zeros(nfft,nFrames);

for k = 1:nFrames
    idx = starts(k):starts(k)+frameLen-1;
    Y(:,k) = fft(x(idx).*window,nfft);
end

Ymag = abs(Y);
Yphase = angle(Y);
Ypower = Ymag.^2;

%% 4. Estimate noise spectrum from noise-only frames

% The enhancement algorithms use only the noisy recording.
% They do not use the generated noise variable.

noiseFrames = find(starts + frameLen - 1 <= noiseSamples);

if length(noiseFrames) < 3
    error('Not enough noise-only frames for estimation.');
end

noisePowerSpectrum = mean(Ypower(:,noiseFrames),2);

% Smooth the estimated noise spectrum
noisePowerSpectrum = movmean(noisePowerSpectrum,5);
noisePowerSpectrum = max(noisePowerSpectrum,1e-12);

fprintf('Noise estimation duration: %.2f seconds\n', noiseDuration);
fprintf('Noise frames used: %d\n', length(noiseFrames));

%% 5. Spectral subtraction

alpha = 1.5;
beta = 0.02;

estimatedNoiseMagnitude = sqrt(noisePowerSpectrum);

cleanMagnitude = max( ...
    Ymag - alpha*estimatedNoiseMagnitude, ...
    beta*Ymag);

Yss = cleanMagnitude .* exp(1i*Yphase);

%% 6. Wiener filtering

estimatedSpeechPower = max(Ypower-noisePowerSpectrum,0);

epsilon = 1e-12;

wienerGain = estimatedSpeechPower ./ ...
    (estimatedSpeechPower + noisePowerSpectrum + epsilon);

wienerGain = min(max(wienerGain,0),1);

Ywiener = wienerGain .* Y;

%% 7. Reconstruct audio using overlap-add

outputSS = zeros(paddedLength,1);
outputWiener = zeros(paddedLength,1);
normalization = zeros(paddedLength,1);

for k = 1:nFrames
    idx = starts(k):starts(k)+frameLen-1;

    frameSS = real(ifft(Yss(:,k),nfft));
    frameWiener = real(ifft(Ywiener(:,k),nfft));

    frameSS = frameSS(1:frameLen).*window;
    frameWiener = frameWiener(1:frameLen).*window;

    outputSS(idx) = outputSS(idx)+frameSS;
    outputWiener(idx) = outputWiener(idx)+frameWiener;

    normalization(idx) = normalization(idx)+window.^2;
end

valid = normalization > 1e-8;

outputSS(valid) = outputSS(valid)./normalization(valid);
outputWiener(valid) = outputWiener(valid)./normalization(valid);

outputSS(~valid) = 0;
outputWiener(~valid) = 0;

% Remove the initial noise-only segment
outputSS = outputSS(noiseSamples+1:noiseSamples+N);
outputWiener = outputWiener(noiseSamples+1:noiseSamples+N);

%% 8. Calculate SNR for evaluation

% The clean speech and actual added noise are used ONLY for evaluation.
% They are not used by either enhancement algorithm.

actualInputSNR = 10*log10( ...
    sum(speech.^2)/(sum((noisySpeech-speech).^2)+eps));

outputSNR_SS = 10*log10( ...
    sum(speech.^2)/(sum((outputSS-speech).^2)+eps));

outputSNR_Wiener = 10*log10( ...
    sum(speech.^2)/(sum((outputWiener-speech).^2)+eps));

fprintf('\nInput SNR: %.2f dB\n', actualInputSNR);
fprintf('Spectral subtraction output SNR: %.2f dB\n', outputSNR_SS);
fprintf('Wiener filter output SNR: %.2f dB\n', outputSNR_Wiener);

%% 9. Save audio files

audiowrite('white_noisy_speech.wav',noisySpeech,Fs);
audiowrite('white_spectral_subtraction.wav',outputSS,Fs);
audiowrite('white_wiener_output.wav',outputWiener,Fs);

fprintf('\nOutput audio files saved successfully.\n');

%% 10. Compare waveforms

t = (0:N-1)/Fs;

figure('Name','White Gaussian Noise - Waveforms');

subplot(3,1,1);
plot(t,noisySpeech);
title('Speech with White Gaussian Noise');
xlabel('Time (seconds)');
ylabel('Amplitude');
grid on;

subplot(3,1,2);
plot(t,outputSS);
title('Spectral Subtraction Output');
xlabel('Time (seconds)');
ylabel('Amplitude');
grid on;

subplot(3,1,3);
plot(t,outputWiener);
title('Wiener Filter Output');
xlabel('Time (seconds)');
ylabel('Amplitude');
grid on;

%% 11. Compare spectrograms

freq = (0:nfft/2)'*Fs/nfft;
frameTimes = (starts-1+frameLen/2)/Fs;
frameTimes = frameTimes(noiseFrames(end)+1:end);
maxFreq = min(8000,Fs/2);

% Calculate spectrograms for the speech portion only
Yspeech = Y(:,noiseFrames(end)+1:end);

figure('Name','White Gaussian Noise - Spectrograms');

subplot(3,1,1);
imagesc((0:size(Yspeech,2)-1)*hop/Fs,freq, ...
    20*log10(abs(Yspeech(1:nfft/2+1,:))+1e-8));
axis xy;
ylim([0 maxFreq]);
title('Noisy Speech');
xlabel('Time (seconds)');
ylabel('Frequency (Hz)');
colorbar;

subplot(3,1,2);
% Use a fresh transform of the enhanced speech
YssPlot = zeros(nfft,size(outputSS,1)*0+size(Yspeech,2));
for k = 1:size(YssPlot,2)
    idx = (k-1)*hop+1;
    idx2 = min(idx+frameLen-1,N);
    temp = zeros(frameLen,1);
    temp(1:idx2-idx+1) = outputSS(idx:idx2);
    YssPlot(:,k) = fft(temp.*window,nfft);
end

imagesc((0:size(YssPlot,2)-1)*hop/Fs,freq, ...
    20*log10(abs(YssPlot(1:nfft/2+1,:))+1e-8));
axis xy;
ylim([0 maxFreq]);
title('Spectral Subtraction Output');
xlabel('Time (seconds)');
ylabel('Frequency (Hz)');
colorbar;

subplot(3,1,3);
YwPlot = zeros(nfft,size(YssPlot,2));
for k = 1:size(YwPlot,2)
    idx = (k-1)*hop+1;
    idx2 = min(idx+frameLen-1,N);
    temp = zeros(frameLen,1);
    temp(1:idx2-idx+1) = outputWiener(idx:idx2);
    YwPlot(:,k) = fft(temp.*window,nfft);
end

imagesc((0:size(YwPlot,2)-1)*hop/Fs,freq, ...
    20*log10(abs(YwPlot(1:nfft/2+1,:))+1e-8));
axis xy;
ylim([0 maxFreq]);
title('Wiener Filter Output');
xlabel('Time (seconds)');
ylabel('Frequency (Hz)');
colorbar;

%% 12. Listen to results

fprintf('Playing noisy speech...\n');
soundsc(noisySpeech,Fs);
pause(duration+1);

fprintf('Playing spectral subtraction output...\n');
soundsc(outputSS,Fs);
pause(duration+1);

fprintf('Playing Wiener output...\n');
soundsc(outputWiener,Fs);

fprintf('\nWhite Gaussian noise experiment completed.\n');
