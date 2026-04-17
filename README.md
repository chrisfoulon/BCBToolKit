# BCBToolKit

Created by Michel Thiebaut de Schotten and Chris Foulon.

> **BCBtoolkit is not approved for clinical use.**
> BCBtoolkit is the property of Chris Foulon and Michel Thiebaut de Schotten.
> Contact: hd.chrisfoulon@gmail.com or michel.thiebaut@gmail.com

Compatible with Mac OSX 10.7–10.10 and Linux (ArchLinux, (K)Ubuntu 14.04/16.04, Debian 8 tested).

---

## Citations

If you use BCBToolKit, please cite:

- Thiebaut de Schotten M. et al. (2014) Damage to white matter pathways in subacute and chronic spatial neglect: a group study and 2 single-case studies with complete virtual "in vivo" tractography dissection. *Cereb Cortex* 24, 691–706.
- Thiebaut de Schotten M. et al. (2011) Atlasing location, asymmetry and inter-subject variability of white matter tracts in the human brain with MR diffusion tractography. *Neuroimage* 54, 49–59.
- Thiebaut de Schotten M. et al. (2012) Monkey to human comparative anatomy of the frontal lobe association tracts. *Cortex* 48, 82–96.
- Catani M. et al. (2012) Short frontal lobe connections of the human brain. *Cortex* 48, 273–291.

---

## Dependencies

- **FSL** — bundled (FMRIB, Oxford, UK). See [FSL wiki](http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/) | [PMID 21979382](http://www.ncbi.nlm.nih.gov/pubmed/21979382) | [PMID 19059349](http://www.ncbi.nlm.nih.gov/pubmed/19059349) | [PMID 15501092](http://www.ncbi.nlm.nih.gov/pubmed/15501092)
- **TrackVis** — bundled. See [trackvis.org](http://trackvis.org)
- **ANTs** — used for Cortical Thickness and Normalisation. See [ANTs](http://stnava.github.io/ANTs)
- Enantiomorphic transformation: Nachev et al. (2008) Enantiomorphic normalization of focally lesioned brains.

---

## Getting started

### Linux

Launch the toolkit by running `BCBToolKit.sh`, or execute it directly from a terminal if `.sh` files are not double-clickable in your file manager.

### macOS

Double-click `BCBToolKit.command`.

### Important

- Only NIfTI (`.nii`) and compressed NIfTI (`.nii.gz`) files are recognised.
- Do not use file or directory names containing spaces, tabs, or parentheses.

---

## Disconnectome Maps — command-line runner (`run_disco.sh`)

`run_disco.sh` is a standalone batch script for computing structural disconnectome
maps from the command line, without the GUI. It can be called from any working
directory; all paths are resolved relative to the script's own location.

### Requirements

Linux system packages (if not already installed):

```bash
sudo apt install libxt6 libglu1-mesa libgl1-mesa-glx
```

All other dependencies (FSL subset, track_vis, bundled libraries) are included
in the BCBToolKit distribution.

### Tractography atlas

A default atlas (178 subjects, 2 mm isotropic MNI space) is bundled in
`Tools/extraFiles/tracks/`.

Larger atlases are available for download:

| Atlas | Link |
|-------|------|
| 2 mm isotropic, 180 subjects | [Dropbox](https://www.dropbox.com/sh/efm3yns3tixsqih/AACmfQv3CVLN2wfbB_cF92uDa?dl=0) |
| 1 mm isotropic, 180 subjects (recommended for 1 mm lesions) | [Dropbox](https://www.dropbox.com/sh/2hnwip97bbuen5a/AAB3M7QCTmWTW9KD6iJteCmga?dl=0) |

To use a custom atlas:
- replace the contents of `Tools/extraFiles/tracks/` with your `.trk` files, or
- pass `-T /path/to/your/tracks/` at runtime.

### Lesion mask resolution

Lesion masks must be registered to MNI space and at the **same resolution** as
the tract atlas. The bundled and 2 mm Dropbox atlases require 2 mm lesions; the
1 mm Dropbox atlas requires 1 mm lesions.

To resample a 1 mm lesion to 2 mm:

```bash
flirt -in lesion_1mm.nii.gz \
      -ref BCBToolKit/Tools/extraFiles/MNI152.nii.gz \
      -out lesion_2mm.nii.gz \
      -applyisoxfm 2 -interp nearestneighbour
```

### Usage

```
Folder mode   (all *.nii / *.nii.gz in a directory):
  run_disco.sh -l LESIONS_DIR -o OUTPUT_DIR [options]

CSV/TSV mode  (explicit list of paths, one per line; optional participant_id column):
  run_disco.sh -l subjects.tsv -o OUTPUT_DIR [options]

BIDS mode     (auto-discovers lesion masks under anat/, writes *_les_SDC.nii.gz in-place):
  run_disco.sh -B BIDS_ROOT [options]
```

### Options

| Flag | Description |
|------|-------------|
| `-o OUTDIR` | Output directory (required with `-l`; ignored with `-B`) |
| `-t THR` | Proportional threshold in [0,1] (default: 0, no thresholding) |
| `-n NCORES` | Number of parallel jobs (default: nCPUs − 1) |
| `-T TRKDIR` | Custom tractography atlas folder |
| `-p PATTERN` | Filename glob for BIDS lesion discovery (default: `*lesion*.nii.gz` and `*lesion*.nii`). May be repeated for OR logic. `participant_id` is always taken from the subject directory name, so extra BIDS entities in the filename (e.g. `_space-MNI152NLin2009cAsym`) are handled automatically. |
| `-w TMPDIR` | Temporary working directory for intermediate files (default: `$TMPDIR/bcb_disco_<PID>`, falls back to `/tmp`). Use this on servers where the BCBToolKit directory is read-only. |
| `-d` | Dry run: print the execution plan without running anything |

### Examples

```bash
# Folder mode
./run_disco.sh -l Lesions/ -o /tmp/results

# Folder mode with custom atlas and threshold
./run_disco.sh -l Lesions/ -o /tmp/results -T /data/HCP_tracks_1mm -t 0.05

# CSV mode — dry run first to verify paths
./run_disco.sh -l subjects.tsv -o /tmp/results -d
./run_disco.sh -l subjects.tsv -o /tmp/results

# BIDS mode
./run_disco.sh -B /data/Clinical_connectome -T /data/HCP_tracks_1mm

# BIDS mode with a non-standard filename convention
./run_disco.sh -B /data/derivatives -p "*space-MNI152NLin2009cAsym*lesion*mask.nii.gz"

# BIDS mode with OR pattern (two naming conventions in the same dataset)
./run_disco.sh -B /data/derivatives -p "*_lesion.nii.gz" -p "*_label-lesion_mask.nii.gz"

# Cluster usage: write temp files to a writable scratch partition
./run_disco.sh -B /data/derivatives -w /scratch/myuser
```
