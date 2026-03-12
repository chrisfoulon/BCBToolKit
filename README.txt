Created by Michel Thiebaut de Schotten and Chris Foulon.
BCBtoolkit is not approved for clinical use.
BCBtoolkit is the property of Chris Foulon and Michel Thiebaut de Schotten.
Contact : hd.chrisfoulon@gmail.com or michel.thiebaut@gmail.com

This software is compatible with 10.7, 10.8, 10.9 and 10.10 versions of Mac OSX and Linux(ArchLinux, (K)Ubuntu 14.04/16.04, Debian 8 tested).

Thanks for citing: 
Thiebaut de Schotten, M., et al. (2014) Damage to white
matter pathways in subacute and chronic spatial neglect: a group study and 
2 single-case studies with complete virtual "in vivo" tractography dissection. 
Cereb Cortex 24, 691-706.
Thiebaut de Schotten M., et al.(2011) Atlasing location, asymmetry and inter-subject variability of white matter tracts in the human brain with MR diffusion tractography. Neuroimage 54, 49-59.
Thiebaut de Schotten M., et al. (2012) Monkey to human comparative anatomy of the frontal lobe association tracts. Cortex 48, 82-96.
Catani M et al. (2012) Short frontal lobe connections of the human brain. Cortex 48, 273-291.


This application uses FSL library created by the FMRIB, Oxford, UK. 
For more information about FSL : http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/
http://www.ncbi.nlm.nih.gov/pubmed/21979382
http://www.ncbi.nlm.nih.gov/pubmed/19059349
http://www.ncbi.nlm.nih.gov/pubmed/15501092

Disconnectome maps mode uses Trackvis library http://trackvis.org

Cortical Thickness and Normalisation use ANTs (Advanced Normalization Tools) http://stnava.github.io/ANTs

Enantiomorphic transformation : Nachev et al. (2008) Enantiomorphic normalization of focally lesioned brains

#### Practical information: ####

The folder of this application includes a default tracts folder.

For OSX users : 

To launch the BCBtoolkit, double-click on the script : BCBToolKit.command

For Linux users : 

To launch the BCBtoolkit, double-click on the script : BCBToolKit.sh (Or launch it in console if .sh scripts are not directly executable by double-click on your OS) 

--------- IMPORTANT ---------
Be careful with file extension, this application recognises only nifti (i.e.: .nii) and compressed nifti (i.e.: .nii.gz) extensions.
Do not use files or directories containing space, tabulation or parenthesis.


#### Disconnectome Maps — command-line runner (run_disco.sh) ####

run_disco.sh is a standalone script for running structural disconnectome maps
in batch from the command line, without the GUI. It can be called from any
working directory.

--- Requirements ---

  System packages (Linux):
    sudo apt install libxt6 libglu1-mesa libgl1-mesa-glx

  All other dependencies (FSL subset, track_vis, bundled libraries) are
  included in the BCBToolKit distribution.

--- Tractography atlas ---

  A default tract atlas (178 subjects, 2 mm isotropic MNI space) is bundled
  in Tools/extraFiles/tracks/.

  Larger atlases are available for download:

    2 mm isotropic, 180 subjects:
      https://www.dropbox.com/sh/efm3yns3tixsqih/AACmfQv3CVLN2wfbB_cF92uDa?dl=0

    1 mm isotropic, 180 subjects (recommended when lesions are at 1 mm):
      https://www.dropbox.com/sh/2hnwip97bbuen5a/AAB3M7QCTmWTW9KD6iJteCmga?dl=0

  To use a custom atlas, either:
    (a) replace the contents of Tools/extraFiles/tracks/ with the new .trk files, or
    (b) pass the -T flag: run_disco.sh ... -T /path/to/your/tracks/

--- Lesion mask resolution ---

  Lesion masks must be registered to MNI space and at the SAME resolution as
  the tract atlas. The bundled and 2 mm Dropbox atlases require 2 mm lesions;
  the 1 mm Dropbox atlas requires 1 mm lesions.

  To resample a 1 mm lesion mask to 2 mm:
    flirt -in lesion_1mm.nii.gz \
          -ref BCBToolKit/Tools/extraFiles/MNI152.nii.gz \
          -out lesion_2mm.nii.gz \
          -applyisoxfm 2 -interp nearestneighbour

--- Usage ---

  Folder mode  (all *.nii / *.nii.gz in a directory):
    run_disco.sh -l LESIONS_DIR -o OUTPUT_DIR [-t THRESHOLD] [-n NCORES] [-T TRACKS_DIR]

  CSV/TSV mode  (explicit list of paths, one per line; optional participant_id column):
    run_disco.sh -l subjects.tsv  -o OUTPUT_DIR [-t THRESHOLD] [-n NCORES] [-T TRACKS_DIR]

  BIDS mode  (auto-discovers *_lesion.nii.gz, writes *_les_SDC.nii.gz in-place):
    run_disco.sh -B BIDS_ROOT               [-t THRESHOLD] [-n NCORES] [-T TRACKS_DIR]

  Options:
    -t  Proportional threshold in [0,1]  (default: 0, no thresholding)
    -n  Number of parallel jobs          (default: nCPUs - 1)
    -T  Custom tractography atlas folder
    -d  Dry run: print the execution plan without running anything

  Examples:
    ./run_disco.sh -l Lesions/ -o /tmp/results
    ./run_disco.sh -l Lesions/ -o /tmp/results -T /data/HCP_tracks_1mm -t 0.05
    ./run_disco.sh -l subjects.tsv -o /tmp/results -d
    ./run_disco.sh -B /data/Clinical_connectome -T /data/HCP_tracks_1mm
