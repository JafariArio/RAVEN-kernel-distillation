# RAVEN reproducibility guide

## 1. Verify the software package

The main launcher is:

`RAVEN_V1_01.m`

Editable source modules are in:

`RAVEN_core/source_modules/`

The launcher rebuilds `RAVEN_core/RAVEN_V1_01_core.m` when the generated core is missing or older than the editable source modules.

## 2. Start RAVEN

In MATLAB R2026a:

```matlab
cd('<path-to-cloned-repository>')
RAVEN_V1_01
```

A successful startup should open the RAVEN GUI without missing-file or missing-module errors.

## 3. Load the synthetic example

Select:

`examples/synthetic/BugCheck_5Classes_10Spectra/`

The example contains five class files. Each file represents one class and contains 1000 spectral-variable rows with one spectral-axis column followed by 10 synthetic spectra. The complete example therefore contains 5 classes and 50 spectra.

All five class files use the same spectral axis.

## 4. Use a short smoke-test configuration

For a first reproduction test:

1. Keep input mode as spectral blocks.
2. Select the **Quick** preset.
3. Keep parallel execution disabled initially for maximum portability.
4. Keep the deterministic seed base at its default value unless testing another configuration.
5. Choose a writable output location.
6. Run the complete pipeline.

The Quick preset reduces cross-validation repeats and search sizes to provide a practical software-function check. It is not intended to reproduce the full publication-scale search budget.

## 5. Confirm successful completion

A successful complete run should create staged output folders corresponding to preprocessing, embedding/PCA selection, teacher search, student search/final confirmation, figures, manifests, and timing records. See `EXPECTED_OUTPUTS.md`.

The required smoke-test criterion is successful end-to-end execution, deterministic configuration recording, and generation of the documented output structure.

## 6. Inspect representative completed outputs

`examples/reference_outputs/` contains a compact representative run supplied with the repository.

Its run manifest records stratified validation with 5 folds, 3 repeats, seed base 2468, five classes, and final selection role BestAccuracy_01.

Its `STEP4_WINNER.txt` records a representative final student with approximately 97.20% student accuracy, 98.00% teacher accuracy, 97.21% macro-F1, and final feature dimension 48.

These values describe the bundled representative output set only. They are not expected values for every synthetic smoke-test execution.

## 7. Blind evaluation

Blind evaluation is performed after model selection using the exported blind-ready package. RAVEN applies the stored preprocessing and selected configuration, refits the selected finalist on the full training data for each requested blind repeat, predicts the blind spectra, and aggregates predicted-label votes.

Majority-vote percentages are predicted-label agreement summaries and are not calibrated probabilities.

## 8. Paper-scale results

The publication datasets and their locked result packages are maintained separately from this compact repository. Users should obtain externally published biological datasets from their original repositories and comply with the original licenses and terms.

The frozen v1.0.0 source should not be edited silently. Any critical post-freeze correction should be released under a new version identifier.
