# RAVEN concise GUI user manual

## Start the application

Open MATLAB R2026a in the `RAVEN_v1.0.0` software folder and run:

```matlab
RAVEN_V1_01
```

## Load data

Use **Folder** or **File(s)** to select spectral-block inputs. For the supplied smoke test, choose `examples/synthetic/BugCheck_5Classes_10Spectra/`. RAVEN should detect five classes and 50 spectra.

## Configure preprocessing and validation

Use **Preprocessing** to inspect the preprocessing pipeline and **Advanced Settings** to review model-search and validation controls. The GUI provides **Quick**, **Accurate**, and **Publish** presets. For the supplied synthetic smoke test, use **Quick**.

All model-dependent preprocessing, including centering and PCA, is fitted within the active training fold.

## Run the pipeline

Choose a writable save folder and click **Run Pipeline**. The pipeline proceeds through preprocessing, PCA/embedding selection, teacher search, student search, final confirmation, reporting, and export.

## Model selection and prediction

The teacher is a Nyström RBF model with a linear multiclass SVM/ECOC head. The deployed student uses fixed nonlinear random features and a ridge readout trained from hard labels and softened teacher scores.

Final candidates can be tracked under BestAccuracy, BestScore, BestSpeed, and BestMemory roles. The locked final configuration is exported for later prediction and blind evaluation.

## Blind evaluation

Use **Blind Test** only after model selection. The blind-ready package stores the preprocessing and selected configuration. Each requested blind repeat refits the selected finalist on the full training data, predicts the blind spectra, and aggregates predicted-label votes. Vote percentages are agreement summaries, not calibrated probabilities.

## Outputs

A successful run creates staged result folders, figures, manifests, timing records, final result spreadsheets, and the blind-ready model package. See `EXPECTED_OUTPUTS.md`.

## Troubleshooting

- Preserve the `RAVEN_core/source_modules/` directory.
- If the generated core is missing or older than the source modules, the launcher rebuilds it automatically.
- Use a writable save directory.
- If parallel execution is unavailable, disable it and run serially.
- Input files in a spectral block must use a common spectral axis.
