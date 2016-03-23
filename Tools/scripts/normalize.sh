#! /bin/bash
#Normalize Patients - Michel Thiebaut de Schotten & Chris Foulon
#$1 = T1Folder $2 LesionFolder $3 ResultFolder $4 templateFile $5 betValue $6 synValue $7keepTmp $8 otherFilesFolder $9 otherResultFolder
[ $# -lt 7 ] && { echo "Usage : $0 T1Folder LesionFolder ResultFolder templateFile betValue synValue keepTmp [-OPTIONAL otherFilesFolder] [-OPTIONAL otherResultFolder]"; exit 1; }

#Those lines are the handling of the script's trace and errors
#Traces and errors will be stored in $3/logNormalisation.txt
echo -n "" > $3/logNormalisation.txt
exec 2>> $3/logNormalisation.txt
set -x

path=${PWD}/Tools
    
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

tmp=$path/tmp/tmpNorm
mkdir -p $tmp
#Toutes les lésions : fslmaths 
#bet (retirer le crane) sur toutes les T1 
#ANTs : matrice de déformation (sur l output de fslmath et bet)
#wSubject1 c la sortie de warp (et donc le résultat final)


cd $1
for f in *nii*
do
    pat=$(basename $f .${f#*.})
    # 1 becomes 0 and 0 becomes 1 !
    lesCommand=""
    if ! [[ $2 == "" ]]
    then 
        $bin/fslmaths $2/$pat.nii* -bin -mul -1 -add 1 $tmp/tmp_les$pat.nii.gz
        lesCommand=" -x $tmp/tmp_les$pat.nii.gz"
    fi
    echo BETVALUE : $5
    # Delete the skull (it's useless ! we don't need skull)
    #Brain extraction Threshold
    $bin/bet $f $tmp/tmp_T1${pat}.nii.gz -f $5
    #ANTMAN will be proud
    $ants/ANTS 3 -m PR[$tmp/tmp_T1$pat.nii.gz,$4,1,4] -i 50x90x50 -o $tmp/tmpwarp${pat}.nii.gz -t Syn["$6"] -r Gauss[3,0]$lesCommand
    $ants/WarpImageMultiTransform 3 $f $3/$pat.nii.gz -R $4 -i $tmp/tmpwarp${pat}Affine.txt $tmp/tmpwarp${pat}InverseWarp.nii.gz
    
    #OPTIONAL apply this deformation also to
    if [ $# -eq 8 ]
    then
        cd $tmp
        #If it is a 4D image, this will split it in vol0000.nii.gz vol0001.nii.gz etc ...
        fslsplit $8/$pat.nii*
        for a in vol*
        do 
            #We add OTH prefix to the result in case of the result destination is the same that the previous transformation.
            $ants/WarpImageMultiTransform 3 $a OTH$a -R $4 -i $tmp/tmpwarp${pat}Affine.txt $tmp/tmpwarp${pat}InverseWarp.nii.gz
        done

        #And you remake the 4D image
        fslmerge -t $9/OTH$pat.nii.gz OTHvol*gz
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
