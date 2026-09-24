# RAVEN v1.0.0

This directory contains the runnable RAVEN MATLAB software package.

## Requirements

- MATLAB R2026a
- Statistics and Machine Learning Toolbox
- Parallel Computing Toolbox optional
- Windows 10/11 tested
- GPU not required

## Run

Open MATLAB, change the current folder to this `RAVEN_v1.0.0` directory, and run:

```matlab
RAVEN_V1_01
```

Keep the folder structure unchanged. The launcher expects `RAVEN_core/` and the worker files to remain beside `RAVEN_V1_01.m`.

## Contents

- `RAVEN_V1_01.m` — launcher
- `build_RAVEN_V1_01_core_from_modules.m` — core builder
- `raven_build_teacher_cache.m` — teacher-cache helper
- `raven_eval_teacher_worker.m` — teacher evaluation worker
- `raven_eval_student_worker.m` — student evaluation worker
- `raven_eval_benchmark_worker.m` — benchmark worker
- `IMG_3820.png` — GUI image asset
- `RAVEN_core/` — generated core and 15 source modules
- `VERSION.txt` — software version

Repository-level supporting materials are kept separately:

- User manual and technical documentation: `../documentation/`
- Synthetic example and representative outputs: `../example/`
- Curated publication results: `../results/`
- MIT license: `../LICENSE`
