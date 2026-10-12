
clc;
clear;
close all;

%% 1. Load noisy speech recording

filename = "C:\Users\ASHOK KUMAR SINGH\Downloads\WhatsApp Audio 2026-10-12 at 09.13.13.wav";

[noisy, Fs] = audioread(filename);

if size(noisy, 2) > 1
    noisy = mean(noisy, 2);
end

noisy = noisy - mean(noisy);
noisy = 0.95 * noisy / (max(abs(noisy)) + eps);

N = length(noisy);
duration = N/Fs;

fprintf('Sampling frequency: %d Hz\n', Fs);
fprintf('Duration: %.2f seconds\n', duration);

%% 2. Frame the audio

frameLen = round(0.025*Fs);
hop = round(0.010*Fs);
nfft = 2^nextpow2(frameLen);

window = 0.5 - 0.5*cos(2*pi*(0:frameLen-1)'/frameLen);

nFrames = max(1, ceil((N-frameLen)/hop) + 1);
paddedLength = (nFrames-1)*hop + frameLen;

noisyPadded = [noisy; zeros(paddedLength-N,1)];
starts = 1 + (0:nFrames-1)*hop;

Y = zeros(nfft,nFrames);

for k = 1:nFrames
    idx = starts(k):starts(k)+frameLen-1;
    frame = noisyPadded(idx);
    Y(:,k) = fft(frame.*window,nfft);
end

Ymag = abs(Y);
Yphase = angle(Y);
noisyPower = Ymag.^2;

%% 3. Estimate noise power over time

noiseWindowDuration = 1.5;
noiseWindowFrames = max(3,round(noiseWindowDuration*Fs/hop));
halfWindow = floor(noiseWindowFrames/2);

noisePower = movmin(noisyPower,[halfWindow halfWindow],2);
noisePower = 1.5*noisePower;
noisePower = movmean(noisePower,5,1);
noisePower = max(noisePower,1e-12);

%% 4. Spectral subtraction

alpha = 1.5;
beta = 0.02;

estimatedNoiseMagnitude = sqrt(noisePower);

cleanMagnitude = max( ...
    Ymag-alpha*estimatedNoiseMagnitude, ...
    beta*Ymag);

Yss = cleanMagnitude.*exp(1i*Yphase);

%% 5. Wiener filtering

estimatedSpeechPower = max(noisyPower-noisePower,0);
epsilon = 1e-12;

wienerGain = estimatedSpeechPower ./ ...
    (estimatedSpeechPower+noisePower+epsilon);

wienerGain = min(max(wienerGain,0),1);
Ywiener = wienerGain.*Y;

%% 6. Detect sudden hammering impacts

frameEnergy = mean(Ymag(1:nfft/2+1,:).^2,1);
energyDB = 10*log10(frameEnergy+eps);

localMedianDB = movmedian(energyDB,[10 10]);

positiveFlux = zeros(1,nFrames);
positiveMagnitude = Ymag(1:nfft/2+1,:);

for k = 2:nFrames
    previousFrame = positiveMagnitude(:,k-1);
    currentFrame = positiveMagnitude(:,k);

    increase = max(currentFrame-previousFrame,0);

    positiveFlux(k) = sum(increase.^2) / ...
        (sum(currentFrame.^2)+eps);
end

% More sensitive detection thresholds
impactFrames = ...
    (energyDB > localMedianDB+4) & ...
    (positiveFlux > 0.02);

fprintf('Potential impact frames detected: %d\n', ...
    sum(impactFrames));

%% 7. Suppress detected impacts

impactGain = ones(1,nFrames);

% Stronger suppression
impactGain(impactFrames) = 0.15;

% Reduce neighboring frames to soften transitions
for k = 1:nFrames
    if impactFrames(k)
        if k > 1 && ~impactFrames(k-1)
            impactGain(k-1) = min(impactGain(k-1),0.70);
        end

        if k < nFrames && ~impactFrames(k+1)
            impactGain(k+1) = min(impactGain(k+1),0.70);
        end
    end
end

% Smooth gain transitions
impactGain = movmean(impactGain,[1 1]);

% Apply suppression to both enhanced outputs
Yss = Yss.*repmat(impactGain,nfft,1);
Ywiener = Ywiener.*repmat(impactGain,nfft,1);

%% 8. Plot the impact suppression gain

frameTimes = (starts-1+frameLen/2)/Fs;

figure('Name','Hammering Suppression Gain');
plot(frameTimes,impactGain);
xlabel('Time (seconds)');
ylabel('Gain');
title('Detected Hammering Suppression');
ylim([0 1.1]);
grid on;

%% 9. Reconstruct audio using overlap-add

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

outputSS = outputSS(1:N);
outputWiener = outputWiener(1:N);

%% 10. Save enhanced audio

audiowrite('spectral_subtraction_output.wav',outputSS,Fs);
audiowrite('wiener_filter_output.wav',outputWiener,Fs);

fprintf('Enhanced audio files saved.\n');

%% 11. Compare waveforms

t = (0:N-1)/Fs;

figure('Name','Speech Enhancement Waveforms');

subplot(3,1,1);
plot(t,noisy);
title('Original Noisy Speech');
xlabel('Time (seconds)');
ylabel('Amplitude');
grid on;

subplot(3,1,2);
plot(t,outputSS);
title('Spectral Subtraction + Impact Suppression');
xlabel('Time (seconds)');
ylabel('Amplitude');
grid on;

subplot(3,1,3);
plot(t,outputWiener);
title('Wiener Filter + Impact Suppression');
xlabel('Time (seconds)');
ylabel('Amplitude');
grid on;

%% 12. Compare spectrograms

freq = (0:nfft/2)'*Fs/nfft;
maxFreq = min(8000,Fs/2);

figure('Name','Speech Enhancement Spectrograms');

subplot(3,1,1);
imagesc(frameTimes,freq, ...
    20*log10(abs(Y(1:nfft/2+1,:))+1e-8));
axis xy;
ylim([0 maxFreq]);
title('Original Noisy Speech');
xlabel('Time (seconds)');
ylabel('Frequency (Hz)');
colorbar;

subplot(3,1,2);
imagesc(frameTimes,freq, ...
    20*log10(abs(Yss(1:nfft/2+1,:))+1e-8));
axis xy;
ylim([0 maxFreq]);
title('Spectral Subtraction Output');
xlabel('Time (seconds)');
ylabel('Frequency (Hz)');
colorbar;

subplot(3,1,3);
imagesc(frameTimes,freq, ...
    20*log10(abs(Ywiener(1:nfft/2+1,:))+1e-8));
axis xy;
ylim([0 maxFreq]);
title('Wiener Filter Output');
xlabel('Time (seconds)');
ylabel('Frequency (Hz)');
colorbar;

%% 13. Listen to results

fprintf('Playing original recording...\n');
soundsc(noisy,Fs);
pause(duration+1);

fprintf('Playing spectral subtraction output...\n');
soundsc(outputSS,Fs);
pause(duration+1);

fprintf('Playing Wiener filter output...\n');
soundsc(outputWiener,Fs);

fprintf('Speech enhancement completed.\n');
