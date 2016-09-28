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

fileName() {
echo -n "$(basename $1 .${1#*.})"
}

################################################################################
## Enantiomorphic tranformation of a T1 with a lesion, method :
## "Enantiomorphic normalization of focally lesioned brains" 
## P. Nachev et al. 2008
## @Paramters : - $1 : the T1 image 
## 	        - $2 : the lesion image with the same name as the T1
##	        - $3 : temporary folder (The result file will be created inside)
## 		- $4 : template to align with, the template must contain the 
## skull
## @output : the file Enantiomorphic${name} (name is the T1 filename) will be 
## stored in the $3 folder)
## $3 will also contain all temporary files created while the function is 
## running
################################################################################
enantiomorphic() {
  ttmp=$3
  name=`fileName $1`
  templateWSkull=$4
  #We reorient images on the MNI coordinates with fslreorient2std
  fslreorient2std $1 $ttmp/$name
  fslreorient2std $2 $ttmp/les$name
  T1=$ttmp/$name
  les=$ttmp/les$name
  # We compute the tranformation between the T1 and the MNI152 WITH the skull 
  # and we apply it to the T1
  flirt -in $T1 -ref $templateWSkull -omat $ttmp/affine.mat \
    -out ${ttmp}/output${name}.nii.gz
  #We also apply the transformation to the lesion file 
  flirt -in $les -ref $templateWSkull -applyxfm -init $ttmp/affine.mat \
    -out ${ttmp}/affineLesion${name}.nii.gz
  #We flip the image 
  fslswapdim ${ttmp}/affineLesion${name}.nii.gz -x y z \
    ${ttmp}/flippedaffine${name}
  #We mask the flipped image with the lesion 
  fslmaths ${ttmp}/output${name}.nii.gz -mas ${ttmp}/flippedaffine${name} \
    ${ttmp}/healthytissue${name}
  #Re-Flip
  fslswapdim ${ttmp}/healthytissue${name} -x y z \
    ${ttmp}/flippedhealthytissue${name}
  #We inverse de transformation matrice
  convert_xfm -omat $ttmp/inverseAffine.mat -inverse $ttmp/affine.mat
  #We apply the inverse of the tranformation on the mask of healthy tissue to 
  #go back to the native space of the T1
  flirt -in ${ttmp}/flippedhealthytissue${name} -ref $T1 -applyxfm \
    -init $ttmp/inverseAffine.mat \
    -out ${ttmp}/nativeflippedhealthytissue${name}.nii.gz
  #We extract the lesionned area of the T1
  fslmaths ${ttmp}/nativeflippedhealthytissue${name}.nii.gz -mas $les \
    ${ttmp}/mnativeflippedhealthytissue${name}
  #We substract this region to the T1 to create a "hole" of 0 values in place
  #of the lesionned area
  fslmaths $les -add 1 -uthr 1 -bin $ttmp/lesionedMask
  fslmaths $T1 -mul $ttmp/lesionedMask $ttmp/T1pitted
  #THE END (We put the final mask inside the native T1 and we have an 
  #healthy T1
  fslmaths $ttmp/T1pitted -add ${ttmp}/mnativeflippedhealthytissue${name} \
  $ttmp/Enantiomorphic${name}
  
}

if [[ $4 != "" ]]
then
  tmp=$path/tmp/tmpCT
  mkdir $tmp
fi;

templateWSkull=$path/extraFiles/MNI152_wskull.nii.gz
priors=$path/extraFiles/Priors
cd $1
for f in *.nii*
do
  finalForm=$f
  filename=$(basename $f .${f#*.})
  res=$2/$filename
  mkdir -p $res
  intermediate=$res/intermediateFiles
  mkdir -p $intermediate
  if [[ $4 != "" ]]
  then
    ll=`ls $4/$filename.nii*`
    enantiomorphic $f $ll $tmp $templateWSkull
    mv $tmp/Enantiomorphic${filename}.nii* $intermediate
    finalForm=$intermediate/Enantiomorphic${filename}.nii.gz
  fi
  $ants/antsCorticalThickness.sh \
    -d 3 \
    -a $finalForm \
    -e $priors/brainWithSkullTemplate.nii.gz -m $priors/brainPrior.nii.gz \
    -p $priors/priors%d.nii.gz \
    -o $intermediate/$filename
  if [[ $4 != "" ]]
  then
    #We extract the lesionned area that we replaced by healthy tissue
    fslmaths $intermediate/${filename}CorticalThickness.nii.gz \
      -mas $tmp/les$f \
      $intermediate/healthyLesionMask
    #And we cut it from the CTMap (We put zeros inside the area)
    fslmaths $intermediate/${filename}CorticalThickness.nii.gz \
      -sub $intermediate/healthyLesionMask \
      $intermediate/${filename}CorticalThickness.nii.gz
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

if [[ $4 != "" ]]
then
  rm -rf $tmp
fi;
