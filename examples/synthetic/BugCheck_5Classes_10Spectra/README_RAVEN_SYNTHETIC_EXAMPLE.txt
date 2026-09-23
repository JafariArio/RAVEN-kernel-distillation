RAVEN Synthetic Example Dataset

Purpose
This dataset is provided only for demonstrating and testing the RAVEN software workflow.

Important
The spectra are synthetic and were generated specifically for software testing.
They are not experimental measurements and must not be used for biological, analytical, diagnostic, or clinical interpretation.

Dataset contents
- Number of classes: 5
- Spectra per class: 10
- Spectral variables per spectrum: 1000
- Total spectra: 50
- All classes use the same spectral-variable axis.

File format
Each class is stored as a separate numeric file.

Column 1
Spectral-variable axis

Columns 2 onward
Individual synthetic spectra

The files follow the standard RAVEN spectral-block input format.

Use with RAVEN
1. Extract the example dataset.
2. Launch RAVEN.
3. Select Folder in Project Setup.
4. Choose the folder containing the five class files.
5. Confirm that five classes and 50 spectra are detected.
6. Inspect the preprocessing preview.
7. Use the Quick preset for a short software test.
8. Run the pipeline and inspect the generated outputs.

Expected use
This example dataset is intended to verify:
- data import
- preprocessing
- PCA
- teacher search
- student search
- final model selection
- result export
- GUI functionality

Software
RAVEN v1.0.0

Dataset type
Synthetic demonstration data created for RAVEN software testing.