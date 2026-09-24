# RAVEN

<p align="center"><img src="RAVEN_v1.0.0/IMG_3820.png" alt="RAVEN logo" width="240"></p>

> **Repository preparation status:** v1.0.0 release preparation is in progress. Do not cite or archive this repository until the v1.0.0 GitHub Release is created.

**RAVEN: Kernel distillation for fast kernel-free spectroscopic bacterial identification**

RAVEN is a MATLAB teacher–student framework for spectroscopic classification. A fold-contained PCA representation is used to train a data-adapted Nyström RBF teacher with a linear multiclass SVM/ECOC head. The teacher's class-score behavior is then distilled into an explicit random-feature student with a ridge readout. After training, the deployed student no longer evaluates kernels against teacher landmarks or training spectra.

## Release

This repository corresponds to the frozen **RAVEN v1.0.0** publication release.

- Publication environment: MATLAB R2026a
- Required toolbox: Statistics and Machine Learning Toolbox
- Optional toolbox: Parallel Computing Toolbox
- Tested operating systems: Windows 10/11
- GPU: not required

## Installation

**Complete software package:** [`RAVEN_v1.0.0/`](RAVEN_v1.0.0/)


1. Clone or download this repository.
2. Open MATLAB R2026a.
3. Change the current directory to `RAVEN_v1.0.0/`.
4. Run:

```matlab
RAVEN_V1_01
```

The complete downloadable software is grouped under `RAVEN_v1.0.0/`. The launcher rebuilds `RAVEN_core/RAVEN_V1_01_core.m` from `RAVEN_core/source_modules/` when the generated core is missing or older than the editable modules.

## Quick reproducibility test

A synthetic five-class example is supplied under `examples/synthetic/BugCheck_5Classes_10Spectra/`.

It contains 5 artificial classes × 10 spectra per class as Excel spectral-block files. The example is for software testing only and is not experimental or biological data.

Recommended smoke test:

1. Launch `RAVEN_V1_01`.
2. Select `examples/synthetic/BugCheck_5Classes_10Spectra/` as the input folder.
3. Confirm detection of 5 classes and 50 spectra.
4. Select the **Quick** preset.
5. Run the pipeline to a writable output folder.
6. Compare the generated folder structure with `examples/reference_outputs/` and `docs/EXPECTED_OUTPUTS.md`.

The repository includes compact text representative outputs for structural and reporting reference. Large MAT files, trained model binaries, and publication-scale biological datasets are intentionally excluded.

## Repository structure

```text
RAVEN-kernel-distillation/
├── RAVEN_v1.0.0/          # complete downloadable MATLAB software
│   ├── RAVEN_V1_01.m
│   ├── build_RAVEN_V1_01_core_from_modules.m
│   ├── raven_build_teacher_cache.m
│   ├── raven_eval_teacher_worker.m
│   ├── raven_eval_student_worker.m
│   ├── raven_eval_benchmark_worker.m
│   ├── IMG_3820.png
│   ├── README.md
│   ├── README_RAVEN_V1_01.txt
│   ├── VERSION.txt
│   ├── LICENSE.txt
│   └── RAVEN_core/
│       ├── RAVEN_V1_01_core.m
│       └── source_modules/
├── docs/
├── examples/
├── results/
├── README.md
├── CITATION.cff
├── AUTHORS.md
├── CHANGELOG.md
└── LICENSE
```

## Documentation

**[Download the full illustrated GUI user manual](docs/RAVEN_GUI_User_Manual_v1.0.0.docx)**


- `docs/REPRODUCIBILITY_GUIDE.md` — end-to-end reproduction workflow
- `docs/DATA_FORMAT.md` — accepted spectral-block input format
- `docs/CONFIGURATION_REFERENCE.md` — default/search configuration reference
- `docs/EXPECTED_OUTPUTS.md` — expected RAVEN output tree
- `docs/SOFTWARE_ENVIRONMENT.md` — software requirements and dependencies
- `docs/DATASET_PROVENANCE_AND_LICENSING.md` — source datasets, identifiers, licensing notes, and redistribution policy
- `docs/USER_MANUAL.md` — concise GUI workflow
- `docs/RAVEN_GUI_User_Manual_v1.0.0.docx` — full illustrated GUI user manual
- `docs/GITHUB_ZENODO_WORKFLOW.md` — release and DOI workflow

The journal manuscript and Supporting Information are intentionally **not** included in this software repository.

## Publication datasets

The original biological datasets analyzed in the paper are **not redistributed in this repository**. Obtain them from the original public sources and follow their provider terms. See `docs/DATASET_PROVENANCE_AND_LICENSING.md`.

The full locked Dataset A/B/C publication-result packages are maintained separately from the source repository. See `results/README.md`.

## Reproducibility scope

The repository provides the frozen source, configuration documentation, synthetic example input, and representative outputs needed to verify the workflow on a new installation. Publication-scale analyses used dataset-specific locked configurations and result packages rather than generic GUI defaults.

## Citation

Citation metadata are provided in `CITATION.cff`. The four software creators and their ORCID identifiers are recorded there.

A Zenodo DOI will be added to this README after the GitHub `v1.0.0` release is archived. The `v1.0.0` Git tag should remain immutable after DOI assignment.

## License

RAVEN source code is released under the **MIT License**. Third-party datasets are not covered by the MIT License and remain subject to the terms of their original providers.

## Contact

Ario Jafari  
Linköping University  
ario.jafari@liu.se
