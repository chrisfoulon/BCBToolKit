#! /bin/bash
#Normalize Patients - Michel Thiebaut de Schotten & Chris Foulon
#$1 = T1Folder $2 LesionFolder $3 ResultFolder $4 templateFile $5 skull_strip
#$6 synValue $7keepTmp $8 lesionMaskingMethod $9 otherFilesFolder
#$10 otherResultFolder
[ $# -lt 8 ] && { echo "Usage : $0 T1Folder LesionFolder ResultFolder \
templateFile skull_strip synValue keepTmp lesionMaskingMethod \
[-OPTIONAL otherFilesFolder] [-OPTIONAL otherResultFolder]"; exit 1; }

#Those lines are the handling of the script's trace and errors
#Traces and errors will be stored in $3/logNormalisation.txt
export PS4='+(${LINENO})'
echo -n "" > $3/logNormalisation.txt
exec 2>> $3/logNormalisation.txt
set -x
set -e

path=${PWD}/Tools

lib=$path/libraries/lib
bin=$path/binaries/bin
ants=$path/binaries/ANTs
export FSLDIR=$path/binaries
#This line prevent missing of the bc binary for ANTs
export PATH=$PATH:$path/binaries/bin:$ants
export ANTSPATH=$ants

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

tmp=$path/tmp/tmpNorm
mkdir -p $tmp
#Toutes les lésions : fslmaths
#bet (retirer le crane) sur toutes les T1
#ANTs : matrice de déformation (sur l output de fslmath et bet)
#wSubject1 c la sortie de warp (et donc le résultat final)

templateWSkull=$path/extraFiles/MNI152_wskull.nii.gz
priors=$path/extraFiles/Priors

cd $1
for f in *nii*
do
    unskulable=$f
    pat=$(basename $f .${f#*.})
    echo $pat
    # 1 becomes 0 and 0 becomes 1 !
    lesCommand=""
    if ! [[ $2 == "" ]]
    then
      if [[ $8 == "Classic" ]]
      then
        fslmaths $2/$pat.nii* -bin -mul -1 -add 1 $tmp/tmp_les$pat.nii.gz
        lesCommand=" -x $tmp/tmp_les$pat.nii.gz"
      elif [[ $8 == "Enantiomorphic" ]]
      then
      	ll=`ls $2/${pat}.nii*`
      	enantiomorphic $f $ll $tmp $templateWSkull
      	mv $tmp/Enantiomorphic${pat}.nii* $3


      	#We will now use this image for the skull stripping
      	unskulable=`ls $3/Enantiomorphic${pat}.nii*`
      else
	       echo "Lesion masking parameter error" >&2
      fi
    fi
    echo BETVALUE : $5
    #If the bet value is greater than 0 we use bet.
    if [[ $5 == "true" ]];
    then
      # Delete the skull

      #Brain extraction Threshold (Leo preproc before the bet)
      #fast -t 1 -n 3 -H 0.1 -I 4 -l 20.0 --nopve -B \
	    #  -o ${tmp}/${pat} ${unskulable}

      # BET2
      #bet2 ${tmp}/${pat}_restore $tmp/tmp_T1${pat}.nii.gz -m -f $5
      antsBrainExtraction.sh -d 3 \
      -a ${unskulable} \
      -e $priors/brainWithSkullTemplate.nii.gz \
      -m $priors/brainPrior.nii.gz \
      -o $tmp/tmp_T1$pat

      mv $tmp/tmp_T1${pat}BrainExtractionBrain.nii.gz $tmp/tmp_T1$pat.nii.gz

      fslcpgeom ${unskulable} $tmp/tmp_T1$pat.nii.gz
    else
      cp ${unskulable} $tmp/tmp_T1$pat.nii.gz
    fi;

    #ANTMAN will be proud
    $ants/ANTS 3 -m PR[$tmp/tmp_T1$pat.nii.gz,$4,1,4] \
      -i 50x90x50 \
      -o $tmp/tmpwarp${pat}.nii.gz \
      -t Syn["$6"] \
      -r Gauss[3,0]$lesCommand

    $ants/WarpImageMultiTransform 3 $f $3/$pat.nii.gz \
      -R $4 \
      -i $tmp/tmpwarp${pat}Affine.txt \
      $tmp/tmpwarp${pat}InverseWarp.nii.gz

    #OPTIONAL apply this deformation also to
    if [ $# -eq 10 ]
    then
        cd $tmp
        #If it is a 4D image, this will split it in vol0000.nii.gz vol0001.nii.gz etc ...
        fslsplit $9/$pat.nii* ifyouusethisprefixyouarereallyawkward
        for a in ifyouusethisprefixyouarereallyawkward*
        do
            #We add OTH prefix to the result in case of the result destination is the same that the previous transformation.
            $ants/WarpImageMultiTransform 3 $a OTH$a \
	      -R $4 \
	      -i $tmp/tmpwarp${pat}Affine.txt \
	      $tmp/tmpwarp${pat}InverseWarp.nii.gz
        done

        #And you remake the 4D image
        fslmerge -t ${10}/OTH$pat.nii.gz OTHifyouusethisprefixyouarereallyawkward*gz
        rm -f $tmp/*ifyouusethisprefixyouarereallyawkward*
        cd $1
    fi

    if [[ $7 == "true" ]]
    then
        cp -vf $tmp/tmpwarp${pat}Affine.txt  $3
        cp -vf $tmp/tmpwarp${pat}InverseWarp.nii.gz $3
        cp -vf $tmp/tmpwarp${pat}Warp.nii.gz $3
    fi
    echo "#"
done
rm -rf $tmp
