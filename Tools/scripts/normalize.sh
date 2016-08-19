#! /bin/bash
#Normalize Patients - Michel Thiebaut de Schotten & Chris Foulon
#$1 = T1Folder $2 LesionFolder $3 ResultFolder $4 templateFile $5 betValue $6 synValue $7keepTmp $8 lesionMaskingMethod $9 otherFilesFolder $10 otherResultFolder
[ $# -lt 8 ] && { echo "Usage : $0 T1Folder LesionFolder ResultFolder templateFile betValue synValue keepTmp lesionMaskingMethod [-OPTIONAL otherFilesFolder] [-OPTIONAL otherResultFolder]"; exit 1; }

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

export LD_LIBRARY_PATH=$lib
export FSLLOCKDIR=""
export FSLMACHINELIST=""
export FSLMULTIFILEQUIT="TRUE"
export FSLOUTPUTTYPE="NIFTI_GZ"
export FSLREMOTECALL=""

tmp=$path/tmp/tmpNorm
mkdir -p $tmp
#Toutes les lésions : fslmaths 
#bet (retirer le crane) sur toutes les T1 
#ANTs : matrice de déformation (sur l output de fslmath et bet)
#wSubject1 c la sortie de warp (et donc le résultat final)

templateWSkull=$path/extraFiles/MNI152_wskull.nii.gz

cd $1
for f in *nii*
do

    unskulable=$f
    pat=$(basename $f .${f#*.})
    # 1 becomes 0 and 0 becomes 1 !
    lesCommand=""
    if ! [[ $2 == "" ]]
    then 
      if [[ $8 == "Classic" ]]
      then
        $bin/fslmaths $2/$pat.nii* -bin -mul -1 -add 1 $tmp/tmp_les$pat.nii.gz
        lesCommand=" -x $tmp/tmp_les$pat.nii.gz"
      elif [[ $8 == "Enantiomorphic" ]]
      then
# 	#We compute the tranformation between the T1 and the MNI152 WITH the skull
# 	ANTS 3 -m PR[$f, $templateWSkull, 1, 4] -i 50x90x50 -o ${tmp}/output${pat}.nii.gz -t Affine[0.25]
# 	#We apply this transformation to the T1 in ${tmp}/affine${pat}.nii.gz
# 	WarpImageMultiTransform 3 $f ${tmp}/affine${pat}.nii.gz -R $templateWSkull $tmp/output${pat}Affine.txt
# 	#We also apply the transformation to the lesion file 
# 	WarpImageMultiTransform 3 $2/$pat.nii* ${tmp}/affineLesion${pat}.nii.gz -R $templateWSkull $tmp/output${pat}Affine.txt
# 	lesionTransformed=${tmp}/affineLesion${pat}.nii.gz
# 	#We flip the image 
# 	fslswapdim ${tmp}/affine${pat} -x y z ${tmp}/flippedaffine${pat}
# 	
# 	#We mask the flipped image with the lesion 
# 	fslmaths ${tmp}/flippedaffine${pat} -mas $lesionTransformed ${tmp}/healthytissue${pat}
# 	#Re-Flip
# # 	fslswapdim ${tmp}/healthytissue${pat} -x y z ${tmp}/flippedhealthytissue${pat}
# 	#We apply the inverse of the tranformation on the mask of healthy tissue to go back to the native space of the T1
# 	WarpImageMultiTransform 3 ${tmp}/healthytissue${pat} ${tmp}/nativeflippedhealthytissue${pat}.nii.gz -R $f -i $tmp/output${pat}Affine.txt
# 	#We mask the healthy tissue with the lesion to have the exact size of the lesion in native space
# 	fslmaths ${tmp}/nativeflippedhealthytissue${pat} -mas $2/$pat.nii* ${tmp}/mnativeflippedhealthytissue${pat}
# 	#We extract the lesionned area of the T1
# 	fslmaths $f -mas $2/$pat.nii* $tmp/lesionedMask
# 	#We substract this region to the T1 to create a "hole" of 0 values in place of the lesionned area
# 	fslmaths $f -sub $tmp/lesionedMask $tmp/T1pitted
# 	#We replace the hole by the healthy tissue mask
# 	fslmaths $tmp/T1pitted -add ${tmp}/mnativeflippedhealthytissue${pat} $3/Enantiomorphic${pat}
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



	#We re-define the image that will be used in bet and to calculate the transformation
	unskulable=$3/Enantiomorphic${pat}
      else 
	echo "Lesion masking parameter error" >&2
      fi
    fi
    echo BETVALUE : $5
    # Delete the skull
    
    #Brain extraction Threshold (Leo preproc before the bet)
    fast -t 1 -n 3 -H 0.1 -I 4 -l 20.0 --nopve -B \
      -o ${tmp}/${pat} ${unskulable}

    # BET2 
    bet2 ${tmp}/${pat}_restore $tmp/tmp_T1${pat}.nii.gz -m -f $5
    #ANTMAN will be proud
    $ants/ANTS 3 -m PR[$tmp/tmp_T1$pat.nii.gz,$4,1,4] -i 50x90x50 -o $tmp/tmpwarp${pat}.nii.gz -t Syn["$6"] -r Gauss[3,0]$lesCommand

    $ants/WarpImageMultiTransform 3 $f $3/$pat.nii.gz -R $4 -i $tmp/tmpwarp${pat}Affine.txt $tmp/tmpwarp${pat}InverseWarp.nii.gz
    
    #OPTIONAL apply this deformation also to
    if [ $# -eq 10 ]
    then
        cd $tmp
        #If it is a 4D image, this will split it in vol0000.nii.gz vol0001.nii.gz etc ...
        fslsplit $9/$pat.nii* ifyouusethisprefixyouarereallyawkward
        for a in ifyouusethisprefixyouarereallyawkward*
        do 
            #We add OTH prefix to the result in case of the result destination is the same that the previous transformation.
            $ants/WarpImageMultiTransform 3 $a OTH$a -R $4 -i $tmp/tmpwarp${pat}Affine.txt $tmp/tmpwarp${pat}InverseWarp.nii.gz
        done

        #And you remake the 4D image
        fslmerge -t ${10}/OTH$pat.nii.gz OTHifyouusethisprefixyouarereallyawkward*gz
        rm -f $tmp/*vol*
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
