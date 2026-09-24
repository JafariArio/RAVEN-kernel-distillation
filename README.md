# RAVEN

<p align="center"><img src="RAVEN_v1.0.0/IMG_3820.png" alt="RAVEN logo" width="240"></p>

> **Repository preparation status:** v1.0.0 release preparation is in progress. Do not cite or archive this repository until the v1.0.0 GitHub Release is created.

**RAVEN: Kernel distillation for fast kernel-free spectroscopic bacterial identification**

RAVEN is a MATLAB teacher–student framework for spectroscopic classification. A fold-contained PCA representation is used to train a data-adapted Nyström RBF teacher with a linear multiclass SVM/ECOC head. The teacher's class-score behavior is distilled into an explicit random-feature student with a ridge readout. Final deployed student inference is kernel-free.

## Download and run

All files needed to run RAVEN, its documentation, and the synthetic example are grouped in one self-contained folder:

**[RAVEN_v1.0.0/](RAVEN_v1.0.0/)**

Requirements:

- MATLAB R2026a
- Statistics and Machine Learning Toolbox
- Parallel Computing Toolbox optional
- Windows 10/11 tested
- GPU not required

After downloading the repository, open MATLAB in `RAVEN_v1.0.0/` and run:

```matlab
RAVEN_V1_01
```

## User manual

**[Download the full illustrated RAVEN User Manual](RAVEN_v1.0.0/docs/RAVEN_User_Manual_v1.0.0.docx)**

Additional technical documentation is in `RAVEN_v1.0.0/docs/`.

## Synthetic example

The included software-test dataset is located at:

`RAVEN_v1.0.0/examples/synthetic/BugCheck_5Classes_10Spectra/`

It contains five artificial classes with 10 spectra per class. These are synthetic software-test data, not experimental or biological measurements.

Compact representative outputs are provided under:

`RAVEN_v1.0.0/examples/reference_outputs/`

## Repository structure

```text
RAVEN-kernel-distillation/
├── RAVEN_v1.0.0/
│   ├── RAVEN_V1_01.m
│   ├── build_RAVEN_V1_01_core_from_modules.m
│   ├── raven_build_teacher_cache.m
│   ├── raven_eval_teacher_worker.m
│   ├── raven_eval_student_worker.m
│   ├── raven_eval_benchmark_worker.m
│   ├── IMG_3820.png
│   ├── VERSION.txt
│   ├── RAVEN_core/
│   ├── docs/
│   └── examples/
├── README.md
├── LICENSE
├── CITATION.cff
├── AUTHORS.md
└── CHANGELOG.md
```

The journal manuscript, Supporting Information, and original third-party biological spectra are intentionally not included in this software repository.

## Citation

Machine-readable citation metadata are provided in `CITATION.cff`. A Zenodo DOI will be added after the immutable `v1.0.0` GitHub release is archived.

## License

RAVEN source code is released under the MIT License. Third-party datasets remain subject to the terms of their original providers.

## Contact

Ario Jafari  
Linköping University  
ario.jafari@liu.se
