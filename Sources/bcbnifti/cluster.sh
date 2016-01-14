#! /bin/bash

path=/home/tolhs/Tractotron/BCBToolKit/Tools
lib=$path/libraries/lib
bin=$path/binaries/bin
ants=$path/binaries/ANTs
les=/home/tolhs/MesDocuments/lesionsToStats
clu=/home/tolhs/MesDocuments/clustest
export FSLDIR=$path/binaries
#This line prevent missing of the bc binary for ANTs
export PATH=$PATH:$path/binaries/bin

export LD_LIBRARY_PATH=$lib
export FSLLOCKDIR=""
export FSLMACHINELIST=""
export FSLMULTIFILEQUIT="TRUE"
export FSLOUTPUTTYPE="NIFTI_GZ"
export FSLREMOTECALL=""

nimg () {
    acc=""
    for i in $@;
    do
        acc="$acc -add $clu/bin$i.nii.gz"
    done;
    fslmaths $clu/bin${1}.nii.gz $acc $clu/sum.nii.gz;
}


for i in {1..324};
do
    fslmaths $les/rSub_${i}.nii* -bin $clu/bin${i}.nii.gz;
done;

sum=$clu/sum.nii.gz

for i in {1..324};
do
    fslmaths $clu/bin${i}.nii.gz -add $sum $sum;
done;

cluster -i /home/tolhs/MesDocuments/clustest/sum.nii.gz -t 3 -o /home/tolhs/MesDocuments/clustest/cluster.nii.gz > /home/tolhs/MesDocuments/clustest/index.txt

nclu=`fslstats /home/tolhs/MesDocuments/clustest/cluster.nii.gz -R | awk '{print $2}' | awk -F. '{print $1}'`

for ((i=1;i<=nclu;i++)); do

    fslmaths /home/tolhs/MesDocuments/clustest/cluster.nii.gz -thr ${i} -uthr ${i} clu_${i}

done
