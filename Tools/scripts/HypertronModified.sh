#! /bin/bash
#hypertron v1.0 - Michel Thiebaut de Schotten & Chris Foulon
[ $# -lt 3 ] && { echo "Usage : $0 LesionFolder ResultDir Threshold"; exit 1; }

#Those lines are the handling of the script's trace and errors
#Traces and errors will be stored in $2/logDisconnectome.txt
export PS4='+(${LINENO})'
echo -n "" > $2/logDisconnectome.txt
exec 2>> $2/logDisconnectome.txt
set -x

path=${PWD}/Tools

lib=$path/libraries/lib
bin=$path/binaries/bin

export LD_LIBRARY_PATH=$lib
export FSLLOCKDIR=""
export FSLMACHINELIST=""
export FSLMULTIFILEQUIT="TRUE"
export FSLOUTPUTTYPE="NIFTI_GZ"
export FSLREMOTECALL=""

hyp=$path/extraFiles/Hypertron
#On tp dans le dossier des lésions
cd $1
#Pour chaque patient du dossier : 
for d in *.nii*
do  
    tmp=$path/tmp/tmpHyp
    mkdir -p $tmp
    cd $hyp
    #on va changer un peu l'ordre, au lieu de faire d'abord applywarp puis trackvis
    #puis fslmaths puis re-applywarp on va boucler sur les numéros de fichiers 
    #et leur appliquer les 4 opérations et on reboucle
    start=000
    maths=""
    for num in {0..999};
    do
        if [[ ${num} -gt 99 ]]
        then 
            start=$num;
        elif [[ ${num} -gt 9 ]]
        then
            start=0$num;
        else 
            start=00$num;
        fi
        #Condition d'arrêt de la boucle, quand il n'y a plus de fichier $start*
        if ! [[ -e ${start}.trk ]]
        then 
            break
        fi
        
        $bin/applywarp -i $1/$d -o $tmp/$start-$d -r  $hyp/l$start.nii.gz -w $hyp/${start}Hypotron_nonlinear.nii.gz
        
        $bin/track_vis $hyp/$start.trk -l 25 250 -roi $tmp/$start-$d -ov $tmp/tmp$start -nr -disable_log
        
        $bin/fslmaths $tmp/tmp$start -bin $tmp/tmpb$start
        
        $bin/applywarp -i $tmp/tmpb$start.nii -o $tmp/${start}disconnectome_$d -r $path/extraFiles/MNI152.nii.gz -w $hyp/${start}Hypertron_nonlinear.nii.gz
        
        #On ajoute les fichiers temporaires disconnectome_...
        if [[ ${num} -eq 0 ]];
        then
            maths=$maths' '$tmp/${start}disconnectome_$d
        else
            maths=$maths' -add '$tmp/${start}disconnectome_$d
        fi
        echo "#"
    done
    cd $1
    #on fait fslmaths sur la chaine que l'on a remplis précédemment
    $bin/fslmaths$maths -div 10 -mas $hyp/mask.nii.gz $2/disconnectome_$d
    
    #With the threshold option you can ... threshold all your resulting disconnectome maps by 0.0 to 1.0
    $bin/fslmaths $2/disconnectome_$d -thr $3 $2/disconnectome_$d
    
    rm -rf $tmp
done
    
echo "#"