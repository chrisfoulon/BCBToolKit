#! /bin/bash

path=/home/tolhs/Tractotron/BCBToolKit/Tools
lib=$path/libraries/lib
bin=$path/binaries/bin
ants=$path/binaries/ANTs
export FSLDIR=$path/binaries
#This line prevent missing of the bc binary for ANTs
export PATH=$PATH:$path/binaries/bin

export LD_LIBRARY_PATH=$lib
export FSLLOCKDIR=""
export FSLMACHINELIST=""
export FSLMULTIFILEQUIT="TRUE"
export FSLOUTPUTTYPE="NIFTI_GZ"
export FSLREMOTECALL=""
