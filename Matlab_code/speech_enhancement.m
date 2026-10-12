clc;
clear;
close all;

%% 1. Load recorded speech

% Select your recorded WAV file from the input folder
filename = 'C:\MATLAB\speech enhancement project\matlab\input\test.wav';

[speech, Fs] = audioread(filename);

% Convert stereo to mono
if size(speech, 2) > 1
    speech = mean(speech, 2);
end

% Remove any hardware DC offset
speech = speech - mean(speech);

% Normalize the recorded speech
speech = speech / (max(abs(speech)) + eps);

fprintf('Sampling frequency: %d Hz\n', Fs);
fprintf('Duration: %.2f seconds\n', length(speech)/Fs);

%% 2. Add white Gaussian noise

rng(1);

inputSNR = 5;                 % SNR in dB

speechPower = mean(speech.^2);
noisePower = speechPower / (10^(inputSNR/10));

noise = randn(size(speech));
noise = noise * sqrt(noisePower);

noisy = speech + noise;

%% 3. Divide the signal into frames

frameLen = round(0.025 * Fs);  % 25 ms
hop = round(0.010 * Fs);       % 10 ms
NFFT = 2^nextpow2(frameLen);

% Hann window
n = (0:frameLen-1)';
win = 0.5 - 0.5*cos(2*pi*n/(frameLen-1));

% Frame starting positions
starts = 1:hop:length(noisy);
numFrames = length(starts);

Y = zeros(NFFT, numFrames);

% FFT of each frame
for m = 1:numFrames
    idx = starts(m);
    last = min(idx + frameLen - 1, length(noisy));

    frame = zeros(frameLen, 1);
    frame(1:last-idx+1) = noisy(idx:last);

    Y(:,m) = fft(frame .* win, NFFT);
end

%% 4. Estimate noise power

% Since this is a controlled experiment, the noise
% power is known from the generated noise.

noisePowerSpectrum = zeros(NFFT, 1);

for m = 1:numFrames
    idx = starts(m);
    last = min(idx + frameLen - 1, length(noise));

    frame = zeros(frameLen, 1);
    frame(1:last-idx+1) = noise(idx:last);

    noiseFFT = fft(frame .* win, NFFT);

    noisePowerSpectrum = noisePowerSpectrum + abs(noiseFFT).^2;
end

noisePowerSpectrum = noisePowerSpectrum / numFrames;

%% 5. Spectral subtraction

alpha = 1.5;
beta = 0.02;

Ymag = abs(Y);
Yphase = angle(Y);

cleanMag = max(Ymag - alpha*sqrt(noisePowerSpectrum), beta*Ymag);

Yss = cleanMag .* exp(1j*Yphase);

%% 6. Wiener filtering

noisyPowerSpectrum = abs(Y).^2;

estimatedSpeechPower = max(noisyPowerSpectrum - noisePowerSpectrum, 0);

epsilon = 1e-10;

wienerGain = estimatedSpeechPower ./ ...
    (estimatedSpeechPower + noisePowerSpectrum + epsilon);

Ywiener = wienerGain .* Y;

%% 7. Reconstruct both outputs using overlap-add (FIXED)

outputSS = zeros(length(noisy), 1);
outputWiener = zeros(length(noisy), 1);
normalization = zeros(length(noisy), 1);

for m = 1:numFrames
    idx = starts(m);
    last = min(idx + frameLen - 1, length(noisy));
    L = last - idx + 1;

    frameSS = real(ifft(Yss(:,m), NFFT));
    frameWiener = real(ifft(Ywiener(:,m), NFFT));

    outputSS(idx:last) = outputSS(idx:last) + frameSS(1:L).*win(1:L);
    outputWiener(idx:last) = outputWiener(idx:last) + frameWiener(1:L).*win(1:L);

    normalization(idx:last) = normalization(idx:last) + win(1:L).^2;
end

% Safe normalization threshold to prevent extreme division spikes at boundaries
valid = normalization > 0.05 * max(normalization);

outputSS(valid) = outputSS(valid) ./ normalization(valid);
outputWiener(valid) = outputWiener(valid) ./ normalization(valid);

% Zero out unreliable window edge samples
outputSS(~valid) = 0;
outputWiener(~valid) = 0;

%% 8. Calculate SNR values

inputSNRMeasured = 10*log10( ...
    sum(speech.^2) / (sum((noisy-speech).^2) + eps));

snrSS = 10*log10( ...
    sum(speech.^2) / (sum((outputSS-speech).^2) + eps));

snrWiener = 10*log10( ...
    sum(speech.^2) / (sum((outputWiener-speech).^2) + eps));

fprintf('\n----- RESULTS -----\n');
fprintf('Input SNR: %.2f dB\n', inputSNRMeasured);
fprintf('Spectral Subtraction SNR: %.2f dB\n', snrSS);
fprintf('Wiener Filter SNR: %.2f dB\n', snrWiener);

%% 9. Plot waveforms

t = (0:length(speech)-1)/Fs;

figure('Name', 'Waveform Comparisons');

subplot(4,1,1);
plot(t, speech);
title('Recorded Clean Speech');
xlabel('Time (s)');
ylabel('Amplitude');
ylim([-1.1 1.1]);

subplot(4,1,2);
plot(t, noisy);
title('Speech with Added Noise');
xlabel('Time (s)');
ylabel('Amplitude');
ylim([-1.5 1.5]);

subplot(4,1,3);
plot(t, outputSS);
title('Spectral Subtraction Output');
xlabel('Time (s)');
ylabel('Amplitude');
ylim([-1.1 1.1]);

subplot(4,1,4);
plot(t, outputWiener);
title('Wiener Filter Output');
xlabel('Time (s)');
ylabel('Amplitude');
ylim([-1.1 1.1]);

%% 10. Plot spectrograms

figure('Name', 'Spectrogram Comparisons');

subplot(3,1,1);
spectrogram(noisy, win, frameLen-hop, NFFT, Fs, 'yaxis');
title('Noisy Speech');

subplot(3,1,2);
spectrogram(outputSS, win, frameLen-hop, NFFT, Fs, 'yaxis');
title('Spectral Subtraction');

subplot(3,1,3);
spectrogram(outputWiener, win, frameLen-hop, NFFT, Fs, 'yaxis');
title('Wiener Filtering');

%% 11. Save audio files

if ~exist('output', 'dir')
    mkdir('output');
end

audiowrite('output/noisy_speech.wav', noisy, Fs);
audiowrite('output/spectral_subtraction.wav', outputSS, Fs);
audiowrite('output/wiener_output.wav', outputWiener, Fs);

%% 12. Play audio

disp('Playing noisy speech...');
soundsc(noisy, Fs);
pause(length(noisy)/Fs + 1);

disp('Playing spectral subtraction output...');
soundsc(outputSS, Fs);
pause(length(outputSS)/Fs + 1);

disp('Playing Wiener filter output...');
soundsc(outputWiener, Fs);

disp('Day 1 MATLAB simulation completed.');