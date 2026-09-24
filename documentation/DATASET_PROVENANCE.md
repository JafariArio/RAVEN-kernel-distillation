# RAVEN Dataset Provenance and Licensing

**Project:** RAVEN — Kernel distillation for fast kernel-free spectroscopic bacterial identification  
**Release:** v1.0.0  
**Prepared:** 2026-09-24

## Purpose

This file records the provenance, source publications, persistent identifiers, licensing information, redistribution status, and RAVEN-specific use of the three public datasets analyzed in the RAVEN study.

The original biological datasets are **not distributed with the RAVEN software repository** unless the source provider's terms explicitly permit redistribution. Users should obtain the original data directly from the cited source repositories and comply with the applicable terms.

Where the licensing status of a deposited dataset is not explicit, this record does not assume that the license of the associated publication automatically applies to the separately deposited data.

## Dataset A — Bacteria-ID Raman benchmark

**Dataset / benchmark:** Bacteria-ID Raman bacterial identification dataset  
**Analytical modality:** Raman spectroscopy

**Original publication:**  
Chi-Sing Ho, Neal Jean, Catherine A. Hogan, Lena Blackmon, Stefanie S. Jeffrey, Mark Holodniy, Niaz Banaei, Amr A. E. Saleh, Stefano Ermon, and Jennifer Dionne.  
“Rapid identification of pathogenic bacteria using Raman spectroscopy and deep learning.”  
*Nature Communications* 10, 4927 (2019).

**Publication DOI:** https://doi.org/10.1038/s41467-019-12898-9  
**Original data/code source:** https://github.com/csho33/bacteria-ID

### Licensing and redistribution

- The associated *Nature Communications* article is distributed under Creative Commons Attribution 4.0 International (CC BY 4.0).
- The Bacteria-ID GitHub repository carries an MIT License for the repository.
- A separate dataset-specific license for every externally hosted spectral file was not assumed.
- **RAVEN redistribution policy:** original Raman spectra are not bundled with this RAVEN repository. Users should obtain the data from the original source and follow the provider's terms.

### Use and modifications in RAVEN

RAVEN used the balanced 30-class Raman reference benchmark.

RAVEN-specific processing included training-fold centering, fold-contained PCA, repeated stratified five-fold cross-validation at the spectrum level when no valid grouping structure was available, five cross-validation repeats with seed base 2468, final confirmation averaged over 10 repeated runs, Nyström-teacher fitting, explicit-student distillation, and generation of RAVEN-specific metrics, figures, timing summaries, configurations, and manifests.

The original biological class labels were not redefined by RAVEN.

**Original study download date:** not recorded in the supplied release records. Source provenance was re-verified on 2026-09-24.

## Dataset B — MS-UMG MALDI-TOF dataset

**Dataset:** MS-UMG — MALDI-TOF Mass Spectra and Resistance Information on Antimicrobials from University Medical Center Göttingen  
**Analytical modality:** MALDI-TOF mass spectrometry  
**Dataset creators:** Youngjun Park, Michael Weig, Christine Noll, Anne-Christin Hauschild, and Oliver Bader  
**Repository:** Zenodo  
**Dataset DOI:** https://doi.org/10.5281/zenodo.13911744

**Associated preprint:**  
Youngjun Park, Michael Weig, Christine Noll, Oliver Bader, and Anne-Christin Hauschild.  
“Effect of Data Heterogeneity in Clinical MALDI-TOF Mass Spectra Profiles on Direct Antimicrobial Resistance Prediction through Machine Learning.”  
bioRxiv (2024).

**Preprint DOI:** https://doi.org/10.1101/2024.10.18.617592

### Licensing and redistribution

- The associated bioRxiv preprint is made available under Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0).
- The Zenodo dataset record is publicly accessible. A standalone dataset license was not assumed from the publication license.
- **RAVEN redistribution policy:** original MS-UMG spectra and source metadata are not redistributed with RAVEN. Users should obtain the dataset from the Zenodo record and comply with the provider's terms.

### Use and modifications in RAVEN

RAVEN used a balanced 15-class identification subset containing 200 spectra per class, for 3,000 development spectra in total.

Separate blind sets were evaluated after model selection, one for each of the 15 evaluated classes, with 60–95 spectra per blind sample and 1,282 blind spectra in total.

RAVEN-specific processing included subset selection, training-fold centering, fold-contained PCA, repeated stratified five-fold cross-validation at the spectrum level when no valid group vector was available, three cross-validation repeats with seed base 2468, final confirmation averaged over 10 repeated runs, exclusion of blind spectra from model selection, and post-selection blind evaluation using the locked RAVEN configuration.

**Original study download date:** not recorded in the supplied release records. Source provenance was re-verified on 2026-09-24.

## Dataset C — ATR-FTIR oral-bacteria dataset

**Dataset:** Accompanying data set to “Differentiation and identification of commensal and pathogenic oral bacteria at strain level using ATR-FTIR spectroscopy”  
**Analytical modality:** ATR-FTIR spectroscopy  
**Dataset creators:** Katharina Anna Frings, Rumjhum Mukherjee, Vivien Schulze, Nils Heine, Nicolas Debener, Janina Bahnemann, Szymon Piotr Szafrański, Meike Stiesch, Katharina Doll-Nikutta, Maria Leilani Torres-Mapa, and Alexander Heisterkamp  
**Repository:** Zenodo  
**Dataset DOI:** https://doi.org/10.5281/zenodo.14856442

**Associated publication:**  
Katharina Anna Frings et al.  
“Differentiation and identification of commensal and pathogenic oral bacteria at strain level using ATR-FTIR spectroscopy.”  
*Analyst* 150 (2025), 3198–3207.

**Publication DOI:** https://doi.org/10.1039/D5AN00165J

### Licensing and redistribution

- The associated *Analyst* article is licensed under Creative Commons Attribution 3.0 Unported (CC BY 3.0).
- The Zenodo record is publicly accessible. The article license was not assumed to govern separately deposited dataset files.
- **RAVEN redistribution policy:** original ATR-FTIR spectra and patient-derived source files are not redistributed with RAVEN. Users should obtain the data directly from the Zenodo repository and comply with the provider's terms.

### Use and modifications in RAVEN

The RAVEN reference panel contained 720 spectra from six oral bacterial species, 120 spectra per species, with 1,001 spectral variables spanning 800–1800 cm⁻¹.

The six species were *Actinomyces naeslundii*, *Aggregatibacter actinomycetemcomitans*, *Fusobacterium nucleatum*, *Porphyromonas gingivalis*, *Streptococcus oralis*, and *Veillonella dispar*.

The patient-derived blind evaluation used 15 blind samples containing 452 spectra in total. Blind spectra were evaluated only after model selection.

RAVEN-specific processing included preparation of the laboratory reference blocks, the stated spectral representation, training-fold centering, fold-contained PCA, repeated stratified five-fold cross-validation at the spectrum level when no valid grouping variable was available, five cross-validation repeats with seed base 2468, final confirmation averaged over 10 repeated runs, and separate post-selection evaluation of patient-derived blind samples.

**Original study download date:** not recorded in the supplied release records. Source provenance was re-verified on 2026-09-24.

## RAVEN-generated synthetic example data

The RAVEN reproducibility materials include a small synthetic example used only to demonstrate and test the software workflow.

The synthetic example contains five artificial classes with 10 spectra per class. It is not derived from Datasets A, B, or C, is not experimental or biological data, and must not be used for biological, analytical, diagnostic, or clinical interpretation.

## Redistribution policy for the public RAVEN release

The public release may include RAVEN source code, documentation, configuration/environment information, synthetic example data, and RAVEN-generated representative outputs.

The public release should **not include copies of the original biological spectra from Datasets A, B, or C** unless explicit redistribution permission is independently confirmed from the applicable dataset license or rights holder.

## Citation requirement

Users reproducing RAVEN analyses should cite both the RAVEN publication/software release and the corresponding original dataset publication/repository record.

## Verification note

This provenance file was prepared from the RAVEN manuscript and original publication/repository records available on 2026-09-24. Licensing terms and repository metadata can change. Users redistributing third-party source data should verify current terms at the original repository before redistribution.
