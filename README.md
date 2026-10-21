# Speech Enhancement Using Spectral Subtraction and Wiener Filtering

A MATLAB reference project for comparing two classical speech-enhancement methods:

- **Spectral subtraction**
- **Wiener filtering**

The project adds controlled synthetic noise to a selected speech recording, estimates the noise spectrum from a noise-only prefix, processes the noisy signal, reconstructs the outputs, and compares them with the clean reference.

> **Status:** MATLAB baseline experiments are running. The results below are preliminary and are not a claim that either method is universally superior. A Code Composer Studio (CCS) port has not yet been completed.

## Repository contents

```text
speech_enhancement/
├── Matlab_code/
│   ├── input/                         # Local input audio samples
│   ├── output graphs for sample 1/     # Saved experiment plots
│   ├── output graphs for sample 2/     # Saved experiment plots
│   ├── pink-like/                      # Saved pink-like noise experiment artifacts
│   ├── noise_detection_removal.m        # Existing team script
│   ├── signaldistortion.m                # Existing team script
│   ├── speech_enhancement.m               # Original team script
│   └── speech_enhancement_v2.m            # Reproducible comparison script
├── output/                              # Generated WAV files (local; normally not committed)
└── README.md
```

Folder names may differ if you organize experiment outputs differently. Generated output WAV files and large plots are best kept out of version control unless they are intentionally included as small, documented examples.

## Requirements

- MATLAB with support for `audioread`, `audiowrite`, `spectrogram`, `soundsc`, and the functions used in the script.
- A speech recording in a format supported by your MATLAB installation. WAV is recommended.
- The script can select a file through a file-picker dialog.

## Run the MATLAB baseline

1. Open the repository in MATLAB or VS Code.
2. Open `Matlab_code/speech_enhancement_v2.m`.
3. Set the experiment parameters near the top of the script:
   ```matlab
   inputSNRdB = 5;
   noiseType = 'white';  % 'white' or 'pink-like'
   ```
4. Run the script and select a speech file when prompted.
5. Review the printed SI-SDR and reference-error metrics, listen to the outputs, and inspect the waveform and spectrogram figures.
6. Copy or rename the generated files after each run if you want to preserve results from different settings. The current script uses the same output naming pattern each run and may overwrite previous files.

The script uses `rng(1, 'twister')` to make the generated noise sequence reproducible for the same input and settings.

## Methods at a glance

### Spectral subtraction

The script estimates a noise magnitude spectrum from noise-only frames and subtracts a scaled estimate from the observed magnitude spectrum. A floor related to the estimated noise spectrum prevents negative/near-zero magnitudes from being used directly. The noisy phase is retained during reconstruction.

### Wiener filtering

The script estimates speech power by subtracting the estimated noise power from the observed power, limits the estimate to non-negative values, and computes a gain between zero and one. That gain is applied to the noisy complex spectrum.

### Framing and reconstruction

The current implementation uses approximately 25 ms frames, a 10 ms hop, a Hann window, FFT-domain processing, and normalized overlap-add reconstruction.

## Preliminary experiment results

The following values were reported by the current MATLAB script. SI-SDR is in dB; higher values indicate a better match to the clean reference under this metric.

### Original speech sample with white noise

| Target input SNR | Measured input SNR | Noisy SI-SDR | Spectral subtraction SI-SDR | Wiener SI-SDR |
|---:|---:|---:|---:|---:|
| 0 dB | 0.00 dB (reported approximately) | 0.01 dB | 8.24 dB | 5.38 dB |
| 5 dB | 5.00 dB | 5.00 dB | 12.13 dB | 10.26 dB |
| 10 dB | 10.00 dB | 10.00 dB | 15.80 dB | 14.89 dB |

### Second speech sample with white noise

| Target input SNR | Measured input SNR | Noisy SI-SDR | Spectral subtraction SI-SDR | Wiener SI-SDR |
|---:|---:|---:|---:|---:|
| 5 dB | 5.00 dB | 5.00 dB | 10.37 dB | 9.51 dB |

### Original speech sample with pink-like noise

| Target input SNR | Measured input SNR | Noisy SI-SDR | Spectral subtraction SI-SDR | Wiener SI-SDR |
|---:|---:|---:|---:|---:|
| 0 dB | 0.02 dB | -0.04 dB | 4.29 dB | 3.60 dB |
| 5 dB | 5.02 dB | 4.99 dB | 7.59 dB | 7.98 dB |

The script also prints a **reference-error ratio**. This is not pure residual-noise SNR; it measures the error relative to the clean reference and can reflect both residual noise and speech distortion.

## Preliminary observations

- Both methods improved SI-SDR over the noisy input in the experiments recorded above.
- Spectral subtraction had higher SI-SDR in the tested white-noise cases.
- Under pink-like noise, spectral subtraction was higher at 0 dB, while Wiener filtering was slightly higher at 5 dB.
- These results are preliminary: only a small number of speech samples and noise conditions have been tested. The second speech sample may contain source noise, so it should not be treated as a verified clean reference unless its quality is confirmed.

## Limitations and next steps

- The noise estimate relies on a **noise-only prefix**. Real recordings may not contain a clearly separated noise-only segment.
- The `pink-like` option is produced by filtering white noise and is an approximation, not a model of every real-world noise.
- SI-SDR alone does not fully capture perceived speech quality, musical noise, muffling, or lost consonants. Listening tests and additional recordings are needed.
- More speech samples, noise types, and repeated controlled tests should be evaluated before drawing broad conclusions.
- The MATLAB implementation is a reference implementation. A C/CCS implementation, target-hardware validation, and real-time performance evaluation remain future work.

## Existing team scripts

The original scripts are retained:

- `Matlab_code/speech_enhancement.m`
- `Matlab_code/signaldistortion.m`
- `Matlab_code/noise_detection_removal.m`

The newer comparison script is `Matlab_code/speech_enhancement_v2.m`. Preserve the original authors' work and clearly describe new contributions in commits and pull requests.

## Reproducibility and output management

- Keep a copy of the parameter settings with each experiment.
- Store each run's metrics and plots under a distinct name or directory before changing parameters.
- Avoid committing large generated audio outputs unless they are necessary for demonstrating the project.
- Check the final Git diff before committing.

## License

No license is specified here. Confirm the repository owner's intended license before redistributing or relicensing the project.
