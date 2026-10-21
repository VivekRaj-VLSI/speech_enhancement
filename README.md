# Speech Enhancement Using Spectral Subtraction and Wiener Filtering

A MATLAB-based Digital Signal Processing (DSP) project exploring speech enhancement in noisy environments using two classical frequency-domain techniques:

- **Spectral Subtraction**
- **Wiener Filtering**

The project compares noisy speech with enhanced outputs using objective metrics, waveform plots, spectrograms, and listening tests. The MATLAB implementation serves as a reference baseline for future embedded DSP development using Code Composer Studio (CCS).

> **Project status:** MATLAB baseline implemented and tested under selected synthetic noise conditions. CCS porting and target-hardware validation are future work.

## Table of Contents

- [Objectives](#objectives)
- [Algorithms](#algorithms)
- [Repository Structure](#repository-structure)
- [Requirements](#requirements)
- [Getting Started](#getting-started)
- [Experimental Setup](#experimental-setup)
- [Results](#results)
- [Evaluation Metrics](#evaluation-metrics)
- [Limitations](#limitations)
- [Future Work](#future-work)
- [Contributors](#contributors)

## Objectives

1. Understand frequency-domain speech enhancement techniques.
2. Implement spectral subtraction and Wiener filtering in MATLAB.
3. Evaluate enhancement performance under different input SNRs and noise conditions.
4. Compare enhanced signals using objective metrics and visualizations.
5. Establish a reference implementation for future embedded DSP development.

## Algorithms

### 1. Spectral Subtraction

Spectral subtraction estimates the noise spectrum and subtracts it from the noisy speech magnitude spectrum.

The noisy signal is represented as:

\[
y[n] = s[n] + d[n]
\]

where \(s[n]\) is the clean speech and \(d[n]\) is additive noise.

A simplified magnitude-spectrum estimate is:

\[
|\hat{S}(k,m)| =
\max\left(|Y(k,m)|-\alpha|\hat{D}(k)|,\,
\beta|\hat{D}(k)|\right)
\]

where:

- \(Y(k,m)\) is the noisy speech spectrum.
- \(\hat{D}(k)\) is the estimated noise spectrum.
- \(\alpha\) is the over-subtraction factor.
- \(\beta\) controls the spectral floor.

The enhanced signal is reconstructed using the estimated magnitude spectrum and the noisy signal's phase.

**Advantages:** Computationally simple and relatively easy to implement.

**Limitations:** Can introduce musical-noise artifacts and speech distortion when noise estimation or subtraction is inaccurate.

### 2. Wiener Filtering

Wiener filtering applies a frequency-dependent gain to suppress components dominated by noise while preserving components likely to belong to speech.

A classical power-spectrum Wiener gain is:

\[
G(k,m)=\frac{P_s(k,m)}{P_s(k,m)+P_d(k)}
\]

where \(P_s\) and \(P_d\) denote estimated speech and noise power spectra.

The enhanced spectrum is:

\[
\hat{S}(k,m)=G(k,m)Y(k,m)
\]

The gain used in this project's implementation is an estimated, power-subtraction-based Wiener-style gain. Its performance depends on the quality of the speech and noise power estimates.

**Advantages:** Provides frequency-dependent attenuation and can produce smoother noise suppression.

**Limitations:** Performance depends on the accuracy of the estimated speech and noise statistics.

## Repository Structure

The main files and experiment artifacts are organized as follows. Some generated figures and logs are stored in experiment-specific folders.

```text
speech_enhancement/
├── Matlab_code/
│   ├── speech_enhancement.m
│   ├── speech_enhancement_v2.m
│   ├── noise_detection_removal.m
│   ├── signaldistortion.m
│   ├── input/
│   │   └── clean_speech.wav
│   ├── output graphs for sample 1/
│   ├── output graphs for sample 2/
│   └── pink-like/
├── output/                  # Generated audio outputs
├── README.md
└── .gitignore
```

- `speech_enhancement_v2.m`: Main experimental MATLAB baseline.
- `speech_enhancement.m`: Original team implementation.
- `noise_detection_removal.m`: Original noise detection/removal script.
- `signaldistortion.m`: Original signal distortion analysis script.
- `input/clean_speech.wav`: Primary sample used in the recorded experiments.
- Experiment folders: Saved figures, spectrograms, and command-window logs.
- `output/`: Generated WAV files from the main script; this directory is ignored by Git by default.

The original team scripts have been retained separately from the new baseline.

## Requirements

- MATLAB (tested with MATLAB R2026a).
- A speech audio file readable by MATLAB.
- Audio playback capability for listening tests.

The main script uses MATLAB functions for audio input/output, signal processing, plotting, and file selection. Availability of individual functions may depend on the installed MATLAB toolboxes.

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/ojas-v/speech_enhancement.git
cd speech_enhancement
```

### 2. Open the project in MATLAB

Open MATLAB and set the current folder to the repository directory.

### 3. Run the baseline

Run the following script from MATLAB:

```matlab
run('Matlab_code/speech_enhancement_v2.m')
```

The script prompts you to select a speech audio file. Select a suitable WAV file when prompted.

### 4. Inspect the outputs

The script generates:

- A noisy speech signal.
- A spectral-subtraction output.
- A Wiener-filter output.
- Waveform comparison plots.
- Spectrogram comparison plots.
- Objective metric values in the command window.

Generated audio files are saved in the repository's root-level `output/` directory.

## Experimental Setup

The current baseline uses synthetic additive noise so that the noise conditions can be controlled.

| Parameter | Configuration |
|---|---|
| Primary sample | `clean_speech.wav` |
| Sampling frequency | 22,050 Hz |
| Frame duration | 25 ms |
| Hop duration | 10 ms |
| Noise-only prefix | 0.5 seconds |
| Noise conditions | White and pink-like |
| Tested input SNRs | 0, 5, and 10 dB for white noise; 0 and 5 dB for pink-like noise |
| Enhancement methods | Spectral subtraction and Wiener-style filtering |

The script estimates the noise spectrum from the noise-only prefix and processes the signal in overlapping frames using windowing and overlap-add reconstruction.

The pink-like noise condition is an approximation produced by filtering white noise; it is not a comprehensive model of real-world background noise.

## Results

The following values were recorded during the current experiments. All entries are SI-SDR values in dB.

### White noise — primary speech sample

| Input SNR | Noisy speech | Spectral subtraction | Wiener filtering |
|---:|---:|---:|---:|
| 0 dB | 0.01 | 8.24 | 5.38 |
| 5 dB | 5.00 | 12.13 | 10.26 |
| 10 dB | 10.00 | 15.80 | 14.89 |

### Pink-like noise — primary speech sample

| Input SNR | Noisy speech | Spectral subtraction | Wiener filtering |
|---:|---:|---:|---:|
| 0 dB | -0.04 | 4.29 | 3.60 |
| 5 dB | 4.99 | 7.59 | 7.98 |

### White noise — second speech sample

| Input SNR | Noisy speech | Spectral subtraction | Wiener filtering |
|---:|---:|---:|---:|
| 5 dB | 5.00 | 10.37 | 9.51 |

**Interpretation:** In these recorded experiments, both methods improved SI-SDR relative to the noisy input. Spectral subtraction performed better in most of the tested conditions, while Wiener filtering performed slightly better in the 5 dB pink-like noise experiment.

These results are preliminary and do not establish that either method is universally superior. The second speech sample may already contain background noise, so its results should be interpreted cautiously. Do not redistribute audio samples without the necessary permissions.

## Evaluation Metrics

### Scale-Invariant Signal-to-Distortion Ratio (SI-SDR)

SI-SDR compares an estimated signal with a clean reference after accounting for an optimal scaling factor.

Higher SI-SDR generally indicates better agreement with the reference signal. However, it is an objective reference-based metric and does not fully capture perceived speech quality or intelligibility.

### Reference-Error Ratio

The script also reports a reference-error ratio based on the squared error between the clean reference and the output.

This metric is labelled separately because it is not a direct measurement of residual-noise SNR. It penalizes both residual noise and differences between the enhanced output and the reference.

### Listening Tests and Visualizations

Waveforms, spectrograms, and listening tests complement the numerical metrics. A higher objective score does not necessarily mean that an output sounds better in every situation.

## Limitations

- Noise is generated synthetically for the documented baseline experiments.
- Noise estimation relies on a noise-only prefix, which may not be available in practical recordings.
- Pink-like noise is an approximation rather than a comprehensive environmental noise model.
- Only a limited number of speech samples and noise conditions have been evaluated.
- Results may change with speech content, noise type, input SNR, and algorithm parameters.
- Real-time processing, computational complexity on target hardware, and fixed-point numerical effects have not yet been validated.
- The reported experiments should not be treated as a comprehensive benchmark against modern speech enhancement methods.

## Future Work

- Expand evaluation to additional speech samples and noise conditions.
- Investigate musical-noise artifacts and speech distortion.
- Tune algorithm parameters using a repeatable evaluation protocol.
- Compare computational complexity, latency, and memory usage.
- Port the validated algorithms to Code Composer Studio.
- Validate real-time performance on the selected DSP hardware.
- Investigate fixed-point implementation where required by the target platform.

## Contributors

This repository contains the original team scripts alongside an additional MATLAB baseline and its experimental documentation.

- **Ojas Vaidya** — MATLAB baseline, experimental evaluation, visualizations, and documentation.
- **Original team contributors** — Existing MATLAB scripts retained in the repository.

---

*This project is intended for educational and experimental use as part of a DSP course project.*
