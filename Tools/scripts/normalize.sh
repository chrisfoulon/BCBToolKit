#! /bin/bash
#Normalize Patients - Michel Thiebaut de Schotten & Chris Foulon
#$1 = T1Folder $2 LesionFolder $3 ResultFolder $4 templateFile $5 skull_strip
#$6 synParam $7keepTmp $8 lesionMaskingMethod $9 otherFilesFolder
#$10 otherResultFolder
[ $# -lt 8 ] && { echo "Usage : $0 T1Folder LesionFolder ResultFolder \
templateFile skull_strip synValue keepTmp lesionMaskingMethod \
[-OPTIONAL otherFilesFolder] [-OPTIONAL otherResultFolder]"; exit 1; }

# print the parameters given to the script by the user
echo "T1Folder: $1"
echo "LesionFolder: $2"
echo "ResultFolder: $3"
echo "templateFile: $4"
echo "skull_strip: $5"
echo "synValue: $6"
echo "keepTmp: $7"
echo "lesionMaskingMethod: $8"
echo "otherFilesFolder: $9"
echo "otherResultFolder: ${10}"

# print the whole command line
echo "Command: $0 $@"


#Those lines are the handling of the script's trace and errors
#Traces and errors will be stored in $3/logNormalisation.txt
export PS4='+(${LINENO})'
echo -n "" > $3/logNormalisation.txt
exec 2>> $3/logNormalisation.txt
set -x
set -e

PATH=$( echo $PATH | tr ":" "\n" | grep  -v "fsl" | tr -s "\n" ":" | sed 's/:$//')
LD_LIBRARY_PATH=$( echo $LD_LIBRARY_PATH | tr ":" "\n" | grep  -v "fsl" | tr -s "\n" ":" | sed 's/:$//')

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
  name=$(basename $1)
  name=${name%%.*}
  echo -n $name
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
## @output : the file Enantiomorphic_${name} (name is the T1 filename) will be
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
  $ttmp/Enantiomorphic_${name}

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
    unskullable=$f
    pat=$(basename $f .${f#*.})
    echo ${pat}
    # 1 becomes 0 and 0 becomes 1 !
    lesCommand=""
    if ! [[ $2 == "" ]]
    then
      if [[ $8 == "Classic" ]]
      then
        fslmaths $2/${pat}.nii* -bin -mul -1 -add 1 $tmp/tmp_les${pat}.nii.gz
        lesCommand=" -x $tmp/tmp_les${pat}.nii.gz"
      elif [[ $8 == "Enantiomorphic" ]]
      then
      	ll=`ls $2/${pat}.nii*`
      	enantiomorphic $f $ll $tmp $templateWSkull
      	mv $tmp/Enantiomorphic_${pat}.nii* $3


      	#We will now use this image for the skull stripping
      	unskullable=`ls $3/Enantiomorphic_${pat}.nii*`
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
	    #  -o ${tmp}/${pat} ${unskullable}

#      -m $priors/brainPrior.nii.gz \
#      -m $priors/brain_stem_cereb_Prior.nii.gz \
      # BET2
      #bet2 ${tmp}/${pat}_restore $tmp/tmp_T1${pat}.nii.gz -m -f $5
      antsBrainExtraction.sh -d 3 \
      -a ${unskullable} \
      -e $priors/brainWithSkullTemplate.nii.gz \
      -m $priors/brainPrior.nii.gz \
      -o $tmp/tmp_T1${pat}

      mv $tmp/tmp_T1${pat}BrainExtractionBrain.nii.gz $tmp/tmp_T1${pat}.nii.gz

      fslcpgeom ${unskullable} $tmp/tmp_T1${pat}.nii.gz
    else
      cp ${unskullable} $tmp/tmp_T1${pat}.nii.gz
    fi;

    fixed_image=$tmp/tmp_T1${pat}.nii.gz;
    moving_image=$4;
    # Because we calculate the transformation template to subject, we inversed the name of the Warped outputs
    # so it correspond to what we what, i.e. Warped is the subject to template transform
    antsRegistration \
    --collapse-output-transforms 0 \
    --dimensionality 3 \
    --interpolation Linear \
    --output [$tmp/transform_${pat}_,$tmp/transform_InverseWarped_${pat}.nii.gz,$tmp/transform_Warped_${pat}.nii.gz] \
    --transform Affine[0.1] \
    --metric MI[$fixed_image,$moving_image,1,32,Regular,0.25] \
    --convergence [1000x500x250x100,1e-08,10] \
    --smoothing-sigmas 3.0x2.0x1.0x0.0 \
    --shrink-factors 8x4x2x1 \
    --use-histogram-matching 1 \
    --transform SyN${6} \
    --metric CC[$fixed_image,$moving_image,1,4] \
    --convergence [100x100x70x20,1e-09,15] \
    --smoothing-sigmas 3.0x2.0x1.0x0.0 \
    --shrink-factors 6x4x2x1 \
    --use-histogram-matching 1 \
    --winsorize-image-intensities [0.01,0.99]${lesCommand}


    affine_tr=`ls $tmp/transform_${pat}_*Affine.mat`
    inverse_syn=`ls $tmp/transform_${pat}_*InverseWarp.nii.gz`
    antsApplyTransforms -d 3 -n Linear -i $f -o $3/registered_${pat}.nii.gz \
    -t ["${affine_tr}",1]  \
    -t ["${inverse_syn}",0] \
    -r $4 -v

    #OPTIONAL apply this deformation also to
    if [ $# -eq 10 ]
    then
        cd $tmp
        #If it is a 4D image, this will split it in vol0000.nii.gz vol0001.nii.gz etc ...
        fslsplit $9/${pat}.nii* please_do_not_use_this_prefix_in_your_images
        for a in please_do_not_use_this_prefix_in_your_images*
        do
            #We add OTH prefix to the result in case of the result destination is the same that the previous transformation.
#            affine_tr=`ls $tmp/transform_${pat}_*Affine.mat`
#            inverse_syn=`ls $tmp/transform_${pat}_*InverseWarp.nii.gz`
            antsApplyTransforms -d 3 -n Linear -i $a -o OTH$a \
                -t ["${affine_tr}",1]  \
                -t ["${inverse_syn}",0] \
                -r $4 -v
        done

        #And you remake the 4D image
        fslmerge -t ${10}/OTH${pat}.nii.gz OTHplease_do_not_use_this_prefix_in_your_images*gz
        rm -f $tmp/*please_do_not_use_this_prefix_in_your_images*
        cd $1
    fi

    if [[ $7 == "true" ]]
    then
        dirname_transfo=$(dirname "${inverse_syn}")
        basename_syn=$(basename "${inverse_syn}")
        syn_temp2pat="${dirname_transfo}/${basename_syn/Inverse/}"
        syn_pat2temp=${inverse_syn}
#        brain_extraction_mask=`ls $tmp/tmp_T1${pat}BrainExtractionMask.nii.gz`
        cp "${affine_tr}" "$3/$(basename ${affine_tr})"
        # remove the Inverse so the patient to template transformation is actually the right one
        cp "${syn_pat2temp}" "$3/${basename_syn/Inverse/}"
        # the template to patient space transform is actually the inverse transform
        cp "${syn_temp2pat}" "$3/${basename_syn}"
#        cp "${brain_extraction_mask}" "$3"
        cp "${tmp}"/*Warped* "$3"
#        cp -vf $tmp/transform_${pat}* $3
    fi
    echo "#"
done
rm -rf $tmp

# Later update for other tranformations in case of multiple files for each
# patient :
# mkdir A;
# mkdir B;
# mv 4DA.nii.gz A/4DA.nii.gz;
# mv 4DB.nii.gz B/4DB.nii.gz;
# fslplit A/4DA.nii.gz; num_a=number_of_volumes
# fslsplit B/4DB.nii.gz;
# fslmerge -t big4D A/vol* B/vol*
# apply transformations
# fslsplit big4D
# fslmerge vol000 to vol$num_a 4DA_normalised
# fslmerge vol$num_a to vol999 4DB_normalised
