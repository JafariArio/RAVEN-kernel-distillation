# RAVEN configuration reference

The canonical configuration is defined in:

`RAVEN_v1.0.0/RAVEN_core/source_modules/01_default_config.m`

This document is a convenience summary only. The source module is authoritative.

## Core defaults

- input mode: `spectra_blocks`
- common-axis mode: preserve
- Savitzky-Golay order: 3
- frame length: 13
- derivative order: 0
- smoothing: enabled
- baseline correction: enabled
- normalization: enabled
- normalization mode: L2
- AsLS lambda: 1e4
- AsLS p: 1e-3
- AsLS iterations: 10
- cross-validation folds: 5
- default CV repeats: 2
- deterministic seed base: 2468
- default split mode: stratified
- parallel execution: disabled by default

## PCA / teacher / student search defaults

PCA candidates:

`[20 30 40 50 60]`

Teacher defaults/search include:

- landmarks: 160 initial teacher value; search `[96 128 160]`
- teacher ranks: `[40 60 80]`
- bandwidth scales: `[1.2 1.5 1.7 2.0]`
- linear SVM box constraints: `[0.05 0.1 0.5 1.0]`

Student search includes:

- explicit feature dimensions: `[48 64 96 128]`
- ridge penalties: `[1e-6 1e-4 1e-2]`
- label/teacher blend coefficients: `[0.05 0.10 0.20]`
- temperatures: `[1 2 5]`
- PCA skip scales: `[0 0.25 0.50]`
- ensemble counts: `[1 3]`

Final-selection policy defaults to `bestscore` and the software can track BestAccuracy, BestScore, BestSpeed, and BestMemory finalist roles.

## Presets

The GUI provides **Quick**, **Accurate**, and **Publish** presets.

For reproducibility-package smoke testing, use **Quick**. Publication analyses should use the configuration documented for the corresponding locked dataset run rather than assuming the generic GUI defaults.
