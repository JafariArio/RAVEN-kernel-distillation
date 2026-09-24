# RAVEN v1.0.0

This folder is the self-contained MATLAB software package for **RAVEN: Kernel distillation for fast kernel-free spectroscopic bacterial identification**.

## Requirements

- MATLAB R2026a
- Statistics and Machine Learning Toolbox
- Parallel Computing Toolbox is optional
- Windows 10/11 tested
- GPU not required

## Run

Open MATLAB, change the current folder to this `RAVEN_v1.0.0` directory, and run:

```matlab
RAVEN_V1_01
```

Keep the complete folder structure unchanged. In particular, the launcher expects the internal `RAVEN_core/` directory to remain beside `RAVEN_V1_01.m`.

## Package contents

- `RAVEN_V1_01.m` — launcher
- `build_RAVEN_V1_01_core_from_modules.m` — core builder
- `raven_build_teacher_cache.m` — teacher-cache helper
- `raven_eval_teacher_worker.m` — teacher evaluation worker
- `raven_eval_student_worker.m` — student evaluation worker
- `raven_eval_benchmark_worker.m` — benchmark worker
- `IMG_3820.png` — GUI image asset
- `RAVEN_core/RAVEN_V1_01_core.m` — generated runnable core
- `RAVEN_core/source_modules/` — 15 modular source files
- `README_RAVEN_V1_01.txt` — original package launch note
- `VERSION.txt` — release version information
- `LICENSE.txt` — MIT License

Do not move individual MATLAB files out of this folder when running the software.
