#!/bin/bash

# if you have multiple seed regions, and a computer with several cores,
# you can try the following to speed up the computations:
#
# (1) create a list called e.g. seeds.txt where for each line there is the
#     complete path to the image. E.g. go to the folder containing all the
#     seed masks and launch this command from the console:
#
#    rm list; for i in `seq 10`; do echo `imglob seed_${i}.nii.gz` >> list; done
#
# (2) Afterwards copy back the list to the directory from which you
# are launching the script
#
# (3) make sure that the variables defining the seed folder and results folder
# are correct
#
# (4) run with:
#     cat list | xargs -n 1 -P 4 ./do_fc_leonardo_xargs.sh

[ $# -lt 4 ] && { echo "Usage : $1 = SubjectFile $2 = seedsFolder(Clusters); \
$3 = target(GrayMatterMask) $4 = resultFolder"; exit 1; }

fileName() {
  name=$(basename $1)
  name=${name%%.*}
  echo -n $name
}

subject=`fileName $1`
#Those lines are the handling of the script's trace and errors
#Traces and errors will be stored in $3/logAnacom.txt
export PS4='+(${LINENO})'
echo -n "" > $4/logs/${subject}.txt
exec 2>> $4/logs/${subject}.txt
set -x


# 4D file of rs data
rs=$1

# Folder containing the seed masks, we will iterate on all nii file inside
seed_folder=$2

path=${PWD}/Tools
tmp=$path/tmp/tmp_funcon

for s in $2/*nii*;
do
    seed=`fileName $s`
    res_seed_folder=$4/${seed}
    mkdir -p $res_seed_folder

    bin_seed=${res_seed_folder}/${seed}
    # binarize seed and target, just in case
    fslmaths $s -div $s ${bin_seed}
    # 3D mask of the seed - I will calculate the mean time course for all the
    # voxels in the mask
    seed_file=${bin_seed}

    # Folder where you want the results to be stored
    results_folder=$res_seed_folder
    # rm -rf ${results_folder}

    # 3D target mask - I will calculate the correlation coefficient and
    # the corresponding Z score, between the mean seed time course and
    # each voxel in this target mask (in this case, the whole gray matter)
    GM=$3

    # OUTPUT
    # correlation coefficient
    corr_results=${results_folder}/${subject}${seed}_corr
    # Z score calculated with Fisher r-to-z transformation
    zcorr_results=${results_folder}/${subject}${seed}_rtoz





    # Please do not modify below this line

    # fslmaths ${GM} -div ${GM} ${GM}


    # extract mean time series from the seed
    fslmeants -i ${rs} -o ${results_folder}/${subject}${seed}_TC.txt \
    -m ${seed_file}

    # create a matrix readable by fsl
    Text2Vest ${results_folder}/${subject}${seed}_TC.txt  \
    ${results_folder}/${subject}${seed}_TC.mat

    # do sbca
    fsl_glm --in=${rs} --design=${results_folder}/${subject}${seed}_TC.mat \
    --mask=${GM} --out=${corr_results} \
    --des_norm --dat_norm --demean

    # do fisher r-to-z transform
    # https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=FSL;a3a5a47c.1110
    # http://vassarstats.net/tabs_rz.html
    # https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=fsl;2633fc4a.1603
    # http://mumfordbrainstats.tumblr.com/post/125523326931/how-to-convert-zstat-images-to-fishers-z

    fslmaths ${GM} -add ${corr_results} ${corr_results}_plus_1
    fslmaths ${GM} -sub ${corr_results} ${corr_results}_minus_1
    fslmaths ${corr_results}_plus_1 -div ${corr_results}_minus_1 \
    ${corr_results}_plus_1_div_corr_minus_1
    fslmaths ${corr_results}_plus_1_div_corr_minus_1 -log \
    -mul 0.5 ${zcorr_results}
    imrm ${corr_results}_plus_1 ${corr_results}_minus_1 \
    ${corr_results}_plus_1_div_corr_minus_1
    rm ${results_folder}/${subject}${seed}_TC.mat
    echo "#"
done;
