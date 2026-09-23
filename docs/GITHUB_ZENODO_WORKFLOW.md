# GitHub–Zenodo release workflow for RAVEN

This repository is intended to be archived through Zenodo's GitHub integration.

## 1. Verify the GitHub repository

Before release, verify that `README.md`, `CITATION.cff`, `LICENSE`, the frozen source, documentation, synthetic example, and representative outputs are present.

Do not commit the original biological datasets or the journal manuscript/Supporting Information.

## 2. Connect GitHub to Zenodo

In Zenodo, link the GitHub account under the account's linked services. Open the Zenodo GitHub integration page, synchronize repositories, locate `JafariArio/RAVEN-kernel-distillation`, and enable it.

Official guidance:
- https://help.zenodo.org/docs/profile/linking-accounts/
- https://help.zenodo.org/docs/github/enable-repository/

## 3. Citation metadata

RAVEN uses `CITATION.cff` for software metadata. It records the software title, version, license, repository URL, four creators, affiliations, and ORCID identifiers.

## 4. Create immutable release v1.0.0

After the repository content and license are final:

1. Create the Git tag `v1.0.0` on the frozen publication commit.
2. Create a GitHub Release named `RAVEN v1.0.0` from that tag.
3. Do not move or recreate the tag after release.

Once the repository is enabled in Zenodo, the release should be ingested automatically.

Official guidance:
- https://help.zenodo.org/docs/github/archive-software/github-upload/

## 5. Record the Zenodo DOI

When Zenodo finishes processing the release:

1. Open the Zenodo software record.
2. Record the DOI assigned to the exact `v1.0.0` software release.
3. Add the DOI to the manuscript Data and Code Availability section.
4. Update the default-branch README with a Zenodo DOI badge/link.
5. If desired, update citation metadata on the default branch, but do not alter the already archived `v1.0.0` tag.

## 6. Future versions

Critical software changes after v1.0.0 should be released under a new semantic version, for example `v1.0.1`.
