# UCIe 2.0 TX System-Level Behavioral Model

## OELP Project — UCIe Transmitter Architecture Study

A standalone MATLAB behavioral model of the UCIe 2.0 transmitter, aligned to the MathWorks UCIe 2.0 Transmitter/Receiver IBIS-AMI Models example. This project implements a complete TX signal chain for system-level analysis of high-speed chiplet-to-chiplet interconnects.

---

## System Parameters (UCIe 2.0 Reference)

| Parameter | Value | Description |
|-----------|-------|-------------|
| Data Rate | 32 GT/s | UCIe base speed |
| Symbol Time (UI) | 31.25 ps | 1/data_rate |
| Samples/UI | 16 | Waveform-domain resolution |
| Signaling | Single-ended NRZ | Binary voltage levels |
| TX Swing | 0.625 V | Output voltage swing |
| TX Rise Time | 12.5 ps | Driver edge rate |
| TX R_out / C_out | 30 Ω / 0.125 pF | Driver output impedance |
| Channel Loss | 2 dB @ 16 GHz | Nyquist insertion loss |
| RX Load | 50 Ω / 0.125 pF | Far-end termination |

---

## Project Files

### Core Model
- **`ucie_tx_model.m`** — Main TX behavioral model with all stages: PRBS/NRZ stimulus → FFE → edge shaping → TX RC → channel → RX load → eye/BER analysis. Run this first to validate the full signal chain.

### Analysis Scripts
- **`ucie_tx_ffe_sweep.m`** — Sweeps FFE presets (no de-emphasis to aggressive) and compares eye height, Q-factor, and BER. Generates side-by-side eye diagrams for visual comparison.
- **`ucie_tx_channel_sweep.m`** — Sweeps channel loss from 0–10 dB to evaluate performance across short/medium/long reach scenarios.
- **`ucie_tx_noise_jitter_analysis.m`** — Sweeps additive noise and random jitter to quantify voltage and timing margins.
- **`ucie_tx_pulse_response.m`** — Computes single-bit pulse response through each stage and decomposes ISI contributions. Shows how FFE reduces post-cursor interference.

### Documentation
- **`docs/model_architecture.md`** — Detailed block-by-block description of the TX model
- **`docs/theory_background.md`** — UCIe system background and signal integrity theory
- **`docs/analysis_guide.md`** — How to run each analysis script and interpret results

---

## Signal Chain Architecture

```
┌─────────┐   ┌─────────┐   ┌──────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐
│  PRBS   │──▶│  TX FFE  │──▶│  Edge    │──▶│  TX RC  │──▶│ Channel │──▶│ RX Load │
│  NRZ    │   │ 2-tap    │   │ Shaping  │   │ R+C     │   │ LPF     │   │ R+C     │
│ Stimulus│   │ c0 + c1  │   │ 1st-order│   │ 30Ω     │   │ 2dB@    │   │ 50Ω     │
│         │   │          │   │ 28 GHz   │   │ 0.125pF │   │ 16GHz   │   │ 0.125pF │
└─────────┘   └─────────┘   └──────────┘   └─────────┘   └─────────┘   └─────────┘
                                                                              │
                                                                              ▼
                                                                    ┌─────────────┐
                                                                    │  Eye / BER  │
                                                                    │  Analysis   │
                                                                    └─────────────┘
```

---

## Quick Start

1. Open MATLAB
2. Navigate to the `OELP_project` folder
3. Run `ucie_tx_model.m` — generates 6 figures (FFE output, waveforms, eye diagram, histograms, frequency response)
4. Run the analysis scripts for parameter exploration

### Expected Output (Main Model)
```
UCIe TX model
Data rate      : 32.00 GT/s
UI             : 31.25 ps
Samples/UI     : 16
Sample rate    : 512.00 GHz

Selected FFE preset  : [0.85  -0.15]
TX swing             : 0.625 V
TX edge f3dB         : 28.00 GHz
Channel pole         : ~31 GHz
Measured BER         : 0.000000e+00
Q-based BER estimate : ~0 (very low)
Eye height           : ~0.35 V
```

---

## Theory Overview

### TX FFE (Feed-Forward Equalizer)
Two-tap FIR filter applied at symbol rate:
```
y[n] = c₀·x[n] + c₁·x[n-1]
```
Post-cursor tap (c₁ < 0) introduces de-emphasis to pre-cancel channel ISI.

### Edge Shaping
First-order low-pass models finite driver bandwidth:
```
f₃dB ≈ 0.35 / t_rise = 0.35 / 12.5 ps = 28 GHz
```

### Channel Model
Single-pole LPF calibrated to target insertion loss:
```
H(f) = 1 / √(1 + (f/f_p)²)
```
where f_p is chosen so |H(16 GHz)| = -2 dB.

### BER Estimation
Dual approach: direct bit comparison + Q-factor analytical estimate:
```
BER ≈ ½ · erfc(Q / √2)
Q = (μ₁ - μ₀) / (σ₁ + σ₀)
```

---

## MathWorks Reference Alignment

This project is aligned to the **MathWorks UCIe 2.0 Transmitter/Receiver IBIS-AMI Models** example from the SerDes Toolbox. Key differences:

| Aspect | MathWorks Example | This Project |
|--------|-------------------|-------------|
| Tool | SerDes Designer + Simulink | Standalone MATLAB scripts |
| FFE | AMI parameter selection | Configurable preset table |
| Channel | S-parameter capable | Single-pole approximation |
| Output | IBIS-AMI export | Eye diagrams + BER metrics |
| Purpose | Industry-standard model generation | Architecture exploration & learning |

The standalone approach allows direct modification of every model parameter without requiring the SerDes Toolbox license.

---

## License
Academic project — OELP submission.
