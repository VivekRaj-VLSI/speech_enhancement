%% Speech Enhancement: Spectral Subtraction vs Wiener Filtering
% Reproducible MATLAB reference implementation.
% Select a clean speech WAV file when prompted.
% This script creates synthetic noise, estimates its spectrum from a
% noise-only prefix of the observed recording, applies both algorithms,
% reconstructs the signal with normalized overlap-add, and evaluates it.
%
% Keep the original team scripts unchanged while validating this version.

clc;
clear;
close all;

%% 1. Select clean speech
[fileName, filePath] = uigetfile( ...
    {'*.wav;*.flac;*.mp3', 'Audio files (*.wav, *.flac, *.mp3)'}, ...
    'Select a clean speech recording');

if isequal(fileName, 0)
    error('No audio file selected. Run the script again and select a file.');
end

inputFile = fullfile(filePath, fileName);
[speech, Fs] = audioread(inputFile);

% Convert stereo to mono and remove DC offset.
if size(speech, 2) > 1
    speech = mean(speech, 2);
end
speech = speech - mean(speech);

peak = max(abs(speech));
if isempty(peak) || peak < eps
    error('The selected audio is silent or nearly silent.');
end
speech = 0.95 * speech / peak;

N = length(speech);
duration = N / Fs;

fprintf('Input file: %s\n', inputFile);
fprintf('Sampling rate: %d Hz\n', Fs);
fprintf('Speech duration: %.2f s\n', duration);

%% 2. Generate reproducible noise and a noise-only prefix
rng(1, 'twister');

inputSNRdB = 0;
noiseOnlyDuration = 0.5;           % seconds
noiseSamples = round(noiseOnlyDuration * Fs);

speechPower = mean(speech.^2);
targetNoisePower = speechPower / (10^(inputSNRdB / 10));

% Select 'white' or 'pink-like' noise.
noiseType = 'pink-like';

totalNoiseSamples = N + noiseSamples;
switch lower(noiseType)
    case 'white'
        noise = randn(totalNoiseSamples, 1);
    case 'pink-like'
        white = randn(totalNoiseSamples, 1);
        noise = filter(1, [1 -0.98], white);
        noise = noise - mean(noise);
    otherwise
        error('Unsupported noiseType: %s', noiseType);
end

% Scale the actual noise realization to the target power.
noise = noise - mean(noise);
noise = noise * sqrt(targetNoisePower / (mean(noise.^2) + eps));

noiseOnly = noise(1:noiseSamples);
noisySpeech = speech + noise(noiseSamples+1 : noiseSamples+N);
recording = [noiseOnly; noisySpeech];

actualInputSNRdB = 10 * log10( ...
    sum(speech.^2) / (sum((noisySpeech - speech).^2) + eps));

fprintf('Noise type: %s\n', noiseType);
fprintf('Target input SNR: %.2f dB\n', inputSNRdB);
fprintf('Measured input SNR: %.2f dB\n', actualInputSNRdB);

%% 3. STFT framing
frameLen = max(16, round(0.025 * Fs));  % 25 ms
hop = max(1, round(0.010 * Fs));        % 10 ms
nfft = 2^nextpow2(frameLen);

% Periodic Hann window. Normalized overlap-add uses window.^2.
n = (0:frameLen-1)';
window = 0.5 - 0.5*cos(2*pi*n/frameLen);

% Pad by one frame on both sides to make boundary reconstruction reliable.
x = [zeros(frameLen, 1); recording; zeros(frameLen, 1)];
lastStart = length(x) - frameLen + 1;
starts = 1:hop:lastStart;
nFrames = numel(starts);

Y = complex(zeros(nfft, nFrames));
for m = 1:nFrames
    idx = starts(m):(starts(m) + frameLen - 1);
    frame = x(idx) .* window;
    Y(:, m) = fft(frame, nfft);
end

Ymag = abs(Y);
Ypower = Ymag.^2;
Yphase = angle(Y);

%% 4. Estimate noise spectrum from noise-only frames
% Convert frame starts from padded coordinates to recording coordinates.
recordingStarts = starts - frameLen;

noiseFrames = find( ...
    recordingStarts >= 1 & ...
    (recordingStarts + frameLen - 1) <= noiseSamples);

if numel(noiseFrames) < 3
    error(['Fewer than 3 complete noise-only frames were available. ' ...
           'Increase noiseOnlyDuration or check the sampling rate.']);
end

% Average power spectrum of observed noise-only frames.
noisePowerSpectrum = mean(Ypower(:, noiseFrames), 2);
noisePowerSpectrum = max(noisePowerSpectrum, 1e-12);
noiseMagnitudeSpectrum = sqrt(noisePowerSpectrum);

fprintf('Noise-only duration: %.2f s\n', noiseOnlyDuration);
fprintf('Noise-only frames used: %d\n', numel(noiseFrames));

%% 5. Spectral subtraction
alpha = 1.5;  % over-subtraction factor
beta = 0.02;  % noise-relative spectral floor

cleanMagnitude = max( ...
    Ymag - alpha * noiseMagnitudeSpectrum, ...
    beta * noiseMagnitudeSpectrum);

Yss = cleanMagnitude .* exp(1i * Yphase);

%% 6. Wiener filtering (power-subtraction gain estimate)
epsilon = 1e-12;
estimatedSpeechPower = max(Ypower - noisePowerSpectrum, 0);
wienerGain = estimatedSpeechPower ./ ...
    (estimatedSpeechPower + noisePowerSpectrum + epsilon);
wienerGain = min(max(wienerGain, 0), 1);

Ywiener = wienerGain .* Y;

%% 7. Inverse FFT and normalized overlap-add
outputSSPadded = zeros(length(x), 1);
outputWienerPadded = zeros(length(x), 1);
olaWeight = zeros(length(x), 1);

for m = 1:nFrames
    idx = starts(m):(starts(m) + frameLen - 1);

    frameSS = real(ifft(Yss(:, m), nfft));
    frameWiener = real(ifft(Ywiener(:, m), nfft));

    outputSSPadded(idx) = outputSSPadded(idx) + ...
        frameSS(1:frameLen) .* window;
    outputWienerPadded(idx) = outputWienerPadded(idx) + ...
        frameWiener(1:frameLen) .* window;
    olaWeight(idx) = olaWeight(idx) + window.^2;
end

valid = olaWeight > 1e-10;
outputSSPadded(valid) = outputSSPadded(valid) ./ olaWeight(valid);
outputWienerPadded(valid) = outputWienerPadded(valid) ./ olaWeight(valid);
outputSSPadded(~valid) = 0;
outputWienerPadded(~valid) = 0;

% Remove the left/right padding, then isolate the speech portion.
recordingStart = frameLen + 1;
recordingEnd = recordingStart + length(recording) - 1;

outputSSRecording = outputSSPadded(recordingStart:recordingEnd);
outputWienerRecording = outputWienerPadded(recordingStart:recordingEnd);

speechStart = noiseSamples + 1;
speechEnd = noiseSamples + N;

outputSS = outputSSRecording(speechStart:speechEnd);
outputWiener = outputWienerRecording(speechStart:speechEnd);

% Fail early if a coding change breaks output dimensions or finiteness.
assert(length(outputSS) == N, 'Spectral subtraction output length mismatch.');
assert(length(outputWiener) == N, 'Wiener output length mismatch.');
assert(all(isfinite(outputSS)), 'Spectral subtraction output contains NaN/Inf.');
assert(all(isfinite(outputWiener)), 'Wiener output contains NaN/Inf.');

%% 8. Evaluation
% For this synthetic experiment the clean reference is available.
% SI-SDR is reference-based and penalizes distortion as well as residual noise.
siSdrNoisy = localSISDR(speech, noisySpeech);
siSdrSS = localSISDR(speech, outputSS);
siSdrWiener = localSISDR(speech, outputWiener);

% Also report reference-error ratio, explicitly labelled as such.
refErrorNoisy = 10*log10(sum(speech.^2) / ...
    (sum((noisySpeech - speech).^2) + eps));
refErrorSS = 10*log10(sum(speech.^2) / ...
    (sum((outputSS - speech).^2) + eps));
refErrorWiener = 10*log10(sum(speech.^2) / ...
    (sum((outputWiener - speech).^2) + eps));

fprintf('\n===== RESULTS =====\n');
fprintf('Measured input SNR:            %8.2f dB\n', actualInputSNRdB);
fprintf('Noisy speech SI-SDR:            %8.2f dB\n', siSdrNoisy);
fprintf('Spectral subtraction SI-SDR:    %8.2f dB\n', siSdrSS);
fprintf('Wiener filter SI-SDR:           %8.2f dB\n', siSdrWiener);
fprintf('\nReference-error ratio (not pure residual-noise SNR):\n');
fprintf('Noisy speech:                   %8.2f dB\n', refErrorNoisy);
fprintf('Spectral subtraction:           %8.2f dB\n', refErrorSS);
fprintf('Wiener filter:                  %8.2f dB\n', refErrorWiener);

%% 9. Save outputs
scriptDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptDir);
outputDir = fullfile(projectRoot, 'output');

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

[~, baseName, ~] = fileparts(fileName);
% Apply one common gain to prevent clipping in all saved outputs.
maxPeak = max([abs(noisySpeech(:)); ...
    abs(outputSS(:)); ...
    abs(outputWiener(:))]);

if maxPeak > 0.999
    commonGain = 0.999 / maxPeak;

    noisySpeech = noisySpeech * commonGain;
    outputSS = outputSS * commonGain;
    outputWiener = outputWiener * commonGain;

    fprintf('Applied common gain %.4f to prevent clipping.\n', commonGain);
end
audiowrite(fullfile(outputDir, [baseName '_noisy.wav']), noisySpeech, Fs);
audiowrite(fullfile(outputDir, [baseName '_spectral_subtraction.wav']), outputSS, Fs);
audiowrite(fullfile(outputDir, [baseName '_wiener.wav']), outputWiener, Fs);

%% 10. Plot waveforms
t = (0:N-1)' / Fs;

figure('Name', 'Speech Enhancement - Waveforms');
subplot(3, 1, 1);
plot(t, noisySpeech);
title('Noisy speech'); xlabel('Time (s)'); ylabel('Amplitude'); grid on;

subplot(3, 1, 2);
plot(t, outputSS);
title('Spectral subtraction'); xlabel('Time (s)'); ylabel('Amplitude'); grid on;

subplot(3, 1, 3);
plot(t, outputWiener);
title('Wiener filtering'); xlabel('Time (s)'); ylabel('Amplitude'); grid on;

%% 11. Plot spectrograms
figure('Name', 'Speech Enhancement - Spectrograms');
subplot(3, 1, 1);
spectrogram(noisySpeech, window, frameLen-hop, nfft, Fs, 'yaxis');
title('Noisy speech');

subplot(3, 1, 2);
spectrogram(outputSS, window, frameLen-hop, nfft, Fs, 'yaxis');
title('Spectral subtraction');

subplot(3, 1, 3);
spectrogram(outputWiener, window, frameLen-hop, nfft, Fs, 'yaxis');
title('Wiener filtering');

fprintf('\nAudio outputs saved in: %s\n', outputDir);

%% 12. Listen to results
fprintf('Playing noisy speech...\n');
soundsc(noisySpeech, Fs);
pause(duration + 1);

fprintf('Playing spectral subtraction output...\n');
soundsc(outputSS, Fs);
pause(duration + 1);

fprintf('Playing Wiener filter output...\n');
soundsc(outputWiener, Fs);

fprintf('\nBaseline experiment completed.\n');

%% Local function: Scale-Invariant Signal-to-Distortion Ratio
function scoreDb = localSISDR(reference, estimate)
    reference = reference(:);
    estimate = estimate(:);

    if length(reference) ~= length(estimate)
        error('SI-SDR inputs must have the same length.');
    end

    reference = reference - mean(reference);
    estimate = estimate - mean(estimate);

    scale = (reference' * estimate) / (reference' * reference + eps);
    target = scale * reference;
    residual = estimate - target;

    scoreDb = 10*log10( ...
        (sum(target.^2) + eps) / (sum(residual.^2) + eps));
end
