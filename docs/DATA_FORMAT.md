# RAVEN spectral-block data format

For the standard `spectra_blocks` input mode, RAVEN accepts `.mat`, `.csv`, `.txt`, `.xlsx`, and `.xls` sources.

For a numeric class block:

- rows = spectral variables
- column 1 = spectral-variable axis
- columns 2 onward = individual spectra
- at least 10 valid rows are required
- values used by a class block must be finite
- class blocks in the same analysis must use matching spectral axes

When a folder is selected, RAVEN scans supported files in the folder. For CSV/TXT files, each valid file is treated as one class. For Excel files, valid sheets can be treated as classes. For MAT files, suitable numeric/table variables can be treated as classes.

The included synthetic example contains:

- 5 class files
- 10 spectra per class
- 50 spectra total
- 1000 spectral variables
- one common axis across all classes

Synthetic example disclaimer: the included spectra were generated solely for demonstrating and testing the RAVEN workflow. They are not experimental measurements and should not be used for biological, analytical, or clinical interpretation.
