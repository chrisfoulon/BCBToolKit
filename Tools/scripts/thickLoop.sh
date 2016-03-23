#! /bin/bash
#Cortical Thickness - Michel Thiebaut de Schotten & Chris Foulon
[ $# -lt 2 ] && { echo "Usage : $0 T1Folder ResultDir"; exit 1; }
#Those lines are the handling of the script's trace and errors
#Traces and errors will be stored in $2/logThickness.txt
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


priors=$path/extraFiles/Priors
cd $1
for f in *.nii*
do
    filename=$(basename $f .${f#*.})
    res=$2/$filename
    mkdir -p $res
    intermediate=$res/intermediateFiles
    mkdir -p $intermediate
    $ants/antsCorticalThickness.sh -d 3 -a $f -e $priors/brainWithSkullTemplate.nii.gz -m $priors/brainPrior.nii.gz -p $priors/priors%d.nii.gz -o $intermediate/$filename
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
