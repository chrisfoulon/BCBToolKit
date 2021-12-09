#! /bin/bash
#hypertron v1.0 - Michel Thiebaut de Schotten & Chris Foulon
[ $# -lt 3 ] && { echo "Usage : $0 LesionFile ConnectomeDir ResultDir Threshold"; exit 1; }

fileName() {
  name=$(basename $1)
  name=${name%%.*}
  echo -n $name
}

subject=`fileName $1`
#Those lines are the handling of the script's trace and errors
#Traces and errors will be stored in $4/logAnacom.txt
export PS4='+(${LINENO})'
echo -n "" > $3/logs/${subject}.txt
exec 2>> $3/logs/${subject}.txt
set -x

path=/data/nimlab/toolkits/BCBToolKit/Tools
tmp=$path/tmp/tmp_disco
lib=$path/libraries/lib
bin=$path/binaries/bin
export PATH=$PATH:$path/binaries/bin
export LD_LIBRARY_PATH=$lib
export FSLLOCKDIR=""
export FSLMACHINELIST=""
export FSLMULTIFILEQUIT="TRUE"
export FSLOUTPUTTYPE="NIFTI_GZ"
export FSLREMOTECALL=""

trks=/data/nimlab/connectomes/tracts/Base10
mkdir -p $tmp

subj_name=`fileName $1`
acc=$tmp/added_maps_$subj_name
fslmaths $1 -mul 0 $acc
num=0
for t in $trks/*.trk;
do
  trk_name="`fileName $t`_bcb_disco"
  tmp_tracto_mask=$tmp/tmp_tracto_${subj_name}
  track_vis $t -l 25 250 -roi $1 -ov $tmp_tracto_mask \
  -nr -disable_log
  fslmaths $tmp_tracto_mask -bin -add $acc $acc
  num=$((num + 1))
  echo "#"
done;
# We divide the result image by the number of tractographies to obtain a
# probabilistic map of the disconnections
fslmaths $acc -div $num $3/$subj_name

# We threshold the result as asked with the last parameter
fslmaths $3/$subj_name -thr $4 $3/$subj_name

fslcpgeom $1 $3/$subj_name

echo "#"
