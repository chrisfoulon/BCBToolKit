#! /bin/bash
#Cortical Thickness - Michel Thiebaut de Schotten & Chris Foulon
[ $# -lt 3 ] && { echo "Usage : $0 T1Folder ResultDir SaveTmp [LesionsFolder]"; exit 1; }
#Those lines are the handling of the script's trace and errors
#Traces and errors will be stored in $2/logThickness.txt
export PS4='+(${LINENO})'
echo -n "" > $2/logThickness.txt
exec 2>> $2/logThickness.txt
set -x

path=${PWD}/Tools
lib=$path/libraries/lib
bin=$path/binaries/bin

ants=$path/binaries/ANTs
#This line prevent missing of the bc binary for ANTs
export PATH=$PATH:$path/binaries/bin

export ANTSPATH=$ants

export FSLDIR=$path/binaries
#This line prevent missing of the bc binary for ANTs
export PATH=$PATH:$path/binaries/bin:$ants

export LD_LIBRARY_PATH=$lib
export FSLLOCKDIR=""
export FSLMACHINELIST=""
export FSLMULTIFILEQUIT="TRUE"
export FSLOUTPUTTYPE="NIFTI_GZ"
export FSLREMOTECALL=""

if [[ $4 == "True" ]]
then
  tmp=$path/tmp/tmpCT
  mkdir=$tmp
fi;

templateWSkull=$path/extraFiles/MNI152_wskull.nii.gz
priors=$path/extraFiles/Priors
cd $1
for f in *.nii*
do
  finalForm=$f
  filename=$(basename $f .${f#*.})
  if [[ $4 == "True" ]]
  then
    #I am so lazy
    pat=$filename
    #We compute the tranformation between the T1 and the MNI152 WITH the skull and we apply it to the T1
      flirt -in $f -ref $templateWSkull -omat $tmp/affine.mat -out ${tmp}/output${pat}.nii.gz
      #We also apply the transformation to the lesion file 
      flirt -in $2/$pat.nii* -ref $templateWSkull -applyxfm -init $tmp/affine.mat -out ${tmp}/affineLesion${pat}.nii.gz
      #We flip the image 
      fslswapdim ${tmp}/affineLesion${pat}.nii.gz -x y z ${tmp}/flippedaffine${pat}
      #We mask the flipped image with the lesion 
      fslmaths ${tmp}/output${pat}.nii.gz -mas ${tmp}/flippedaffine${pat} ${tmp}/healthytissue${pat}
      #Re-Flip
      fslswapdim ${tmp}/healthytissue${pat} -x y z ${tmp}/flippedhealthytissue${pat}
      #We inverse de transformation matrice
      convert_xfm -omat $tmp/inverseAffine.mat -inverse $tmp/affine.mat
      #We apply the inverse of the tranformation on the mask of healthy tissue to go back to the native space of the T1
      flirt -in ${tmp}/flippedhealthytissue${pat} -ref $f -applyxfm -init $tmp/inverseAffine.mat -out ${tmp}/nativeflippedhealthytissue${pat}.nii.gz
      #We extract the lesionned area of the T1
      fslmaths ${tmp}/nativeflippedhealthytissue${pat}.nii.gz -mas $2/$pat.nii* ${tmp}/mnativeflippedhealthytissue${pat}
      #We substract this region to the T1 to create a "hole" of 0 values in place of the lesionned area
      fslmaths $2/$pat.nii* -add 1 -uthr 1 -bin $tmp/lesionedMask
      fslmaths $f -mul $tmp/lesionedMask $tmp/T1pitted
      fslmaths $tmp/T1pitted -add ${tmp}/mnativeflippedhealthytissue${pat} $3/Enantiomorphic${pat}
  else 
    echo "Lesion masking parameter error" >&2
  fi
  res=$2/$filename
  mkdir -p $res
  intermediate=$res/intermediateFiles
  mkdir -p $intermediate
  $ants/antsCorticalThickness.sh -d 3 -a $finalForm -e $priors/brainWithSkullTemplate.nii.gz -m $priors/brainPrior.nii.gz -p $priors/priors%d.nii.gz -o $intermediate/$filename
  if [[ $4 == "True" ]]
  then
    #We extract the lesionned area that we replaced by healthy tissue
    fslmaths $intermediate/${filename}CorticalThickness.nii.gz -mas $5/$pat.nii* $intermediate/healthyLesionMask
    #And we cut it from the CTMap (We put zeros inside the area)
    fslmaths $intermediate/${filename}CorticalThickness.nii.gz -sub $intermediate/healthyLesionMask $intermediate/${filename}CorticalThickness.nii.gz
  fi;
  #On sépare les fichiers finaux des intermédiaires
  mv $intermediate/${filename}CorticalThickness.nii.gz $res
  mv $intermediate/*png $res
  #Si on a coché l'option dans la BCBTB on conserve les fichiers intermédiaires
  if [[ $3 == "false" ]]
  then
      rm -r $intermediate
  fi
  echo "#PATIENT#"
done

if [[ $4 == "True" ]]
then
  rm -rf $tmp
fi;
