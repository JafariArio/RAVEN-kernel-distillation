# Expected RAVEN outputs

A successful complete run normally creates a run directory containing the following categories.

## Top-level records

- `RUN_MANIFEST.txt` / `.mat`
- `OUTPUT_MANIFEST.txt` / `.mat`
- `OUTPUT_METADATA.xlsx`
- `TIMING_REPORT.txt` / `.xlsx`

These records document the run state, output inventory, metadata, and timing.

## Step 0 — preprocessing

Directory: `STEP0_PREPROC/`

Typical files include `DATA_DISPOSITION.xlsx`, `PREPROCESSED_DATA.mat`, and split/group summaries.

## Step 1 — PCA/embedding selection

Directory: `STEP1_EMBEDDING/`

Typical files include `STEP1_RESULTS.mat` and `STEP1_RESULTS.xlsx`.

## Step 2 — teacher/localization search

Directory: `STEP2_LOCALIZATION/`

Typical files include `STEP2_RESULTS.mat` and `STEP2_RESULTS.xlsx`.

## Step 3 — student/local approximation

Directory: `STEP3_LOCALAPPROX/`

Typical files include `STEP3_RESULTS.mat`, `STEP3_RESULTS.xlsx`, and teacher-comparison exports.

## Step 4 — final confirmation

Directory: `STEP4_FINAL/`

Typical files include `FINAL_RESULTS.xlsx`, `FINAL_RESULTS_SUMMARY.mat`, `STEP4_FINALISTS.txt`, `STEP4_SELECTION_SUMMARY.xlsx`, `STEP4_WINNER.txt`, and `FINAL_WINNER_BLIND_MODEL.mat`.

## Figures and ablation exports

`FIGURES/` contains pipeline figures such as confusion matrices, ROC plots, and search plots.

`ABLATION_EXPORT/` may contain ablation-selection tables and summaries.

## Representative output tree

A compact representative output set is included at:

`example/synthetic/BugCheck_5Classes_10Spectra/reference_outputs/`

Use it to check file naming, folder organization, and report structure. It is a precomputed representative run and should not be treated as the exact numerical output of the included synthetic smoke-test input.
