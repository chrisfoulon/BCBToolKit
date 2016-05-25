#! /bin/bash
#AnaCOM2 - Leonardo Cerliani & Michel Thiebaut de Schotten & Chris Foulon 
[ $# -lt 1 ] && { echo "Usage : $0 "; exit 1; }

#Those lines are the handling of the script's trace and errors
#Traces and errors will be stored in $3/logAnacom.txt
export PS4='+(${LINENO})'
echo -n "" > $3/logAnacom.txt
exec 2>> $3/logAnacom.txt
set -x

path=${PWD}/Tools
    
lib=$path/libraries/lib
bin=$path/binaries/bin
export FSLDIR=$path/binaries
#This line prevent missing of the bc binary for ANTs
export PATH=$PATH:$path/binaries/bin

export LD_LIBRARY_PATH=$lib
export FSLLOCKDIR=""
export FSLMACHINELIST=""
export FSLMULTIFILEQUIT="TRUE"
export FSLOUTPUTTYPE="NIFTI_GZ"
export FSLREMOTECALL="" 
#IMPORTANT
export FSLTCLSH=$bin/fsltclsh



# Parameters to be changed:
# (1) subject name/number.
# (2) base directory
# (3) TR
#
# The script expects to find the following file naming and folder scheme:
#
#  0051159
#  |
#  |____RS
#  |    |
#  |    |_____0051159_RS.nii.gz
#  |
#  |____T1
#       |
#       |_____0051159_T1.nii.gz
#
# From this example it should be clear that the folder containing the data
# has the name of the subject number/name
#
# The script assumes that FSL is installed and available in the path, so 
# that fsl commands (e.g. fsl_glm) can be called directly without having
# to specify the path.
#
# In order to run ICA AROMA, Python 2.7 must be installed, and the directory
# containing the scripts must be downloaded from https://github.com/rhr-pruim/ICA-AROMA
#

subj=0051159

TR=2  # necessary for estimating the sigma of the bandpass temporal filters

bd=/Volumes/Cibele/preprocess_rsfmri/${subj}

f1_kernel=/Volumes/Cibele/preprocess_rsfmri/f1_kernel.nii.gz

AROMAdir=/Applications/fsl/ICA-AROMA-master


###############################################################################
# END OF PARAMETERS TO BE MODIFIED





# FAST for field bias estimation ONLY. This is functional to obtaining a better
# skull stripping, carried out in the subsequent BET2
fast -t 1 -n 3 -H 0.1 -I 4 -l 20.0 --nopve -B \
     -o ${bd}/T1/${subj}_T1_restore ${bd}/T1/${subj}_T1

rm ${bd}/T1/${subj}_T1_restore_seg



# BET2
bet2 ${bd}/T1/${subj}_T1_restore ${bd}/T1/${subj}_T1_restore_brain -m


# FAST for estimating the location of WM and CSF, whose time course will be used
# later for nuisance regression
mkdir ${bd}/T1/fast
fast -t 1 -n 3 -H 0.1 -I 4 -l 20.0 -o ${bd}/T1/fast/${subj}_T1_restore_brain \
                                      ${bd}/T1/${subj}_T1_restore_brain



# Basic FEAT preprocessing, including:
#
# (1) MCFLIRT correcting for estimated motion
# (2) slice-time of acquisition
# (3) highpass temporal filter (by fitting a straight line)
# (4) intensity normalization
# (5) smoothing
#
# Steps (2) and (5) require manually inputting parameters by the user. In addition,
# Some of the parameters displayed in the feat log are difficult to retrieve (e.g. for Susan),
# Therefore the easiest way to perform this preprocessing part is to create a design.fsf 
# using the Feat_gui, and the running it using the feat command. 
#
# P.S. this will be replaced later by a function that takes in subj-specific arguments
# and modifies a design.fsf template
feat ${bd}/design_preproc.fsf

ffdata=${bd}/preproc.feat/filtered_func_data.nii.gz



# Estimation of WM and CSF time courses
# (1) Register the T1_restore_brain to the EPI using the previously estimated transformation in 
#     preproc.feat/reg/highres2example_func.mat. 
# (2) Segment the T1_restore_brain_epispace and take the p=0.9 of WM (pve_2) and CSF (pve_0)
# (3) Use them to extract the mean time course in the filtered_func_data
# (4) Compute their first derivative
WM_CSF_conf_dir=${bd}/preproc.feat/WM_CSF_conf
mkdir ${WM_CSF_conf_dir}

flirt -in ${bd}/T1/${subj}_T1_restore_brain.nii.gz \
      -applyxfm -init ${bd}/preproc.feat/reg/highres2example_func.mat \
      -out ${WM_CSF_conf_dir}/T1_restore_brain_epispace \
      -paddingsize 0.0 -interp trilinear \
      -ref ${bd}/preproc.feat/example_func.nii.gz

T1_epi_seg=${WM_CSF_conf_dir}/fast_T1epispace
mkdir ${T1_epi_seg}
fast -t 1 -n 3 -H 0.1 -I 4 -l 20.0 \
     -o ${T1_epi_seg}/T1_restore_brain_epispace \
        ${WM_CSF_conf_dir}/T1_restore_brain_epispace


# threshold WM (pve_2) and CSF (pve_0) pve to 0.9, and extract the eigTC from the
# filtered_func_data
fslmaths ${T1_epi_seg}/T1_restore_brain_epispace_pve_0.nii.gz \
         -thr 0.9 -bin ${T1_epi_seg}/CSF_thr09

fslmeants -i ${ffdata} -m ${T1_epi_seg}/CSF_thr09 --eig -v -o ${bd}/preproc.feat/WM_CSF_conf/CSF_1EigTC

fslmaths ${T1_epi_seg}/T1_restore_brain_epispace_pve_2.nii.gz \
         -thr 0.9 ${T1_epi_seg}/WM_thr09

fslmeants -i ${ffdata} -m ${T1_epi_seg}/WM_thr09 --eig -v -o ${bd}/preproc.feat/WM_CSF_conf/WM_1EigTC

#Alternative to compute the following code
#If t0 is the first number, t1 the second etc ... so :
# ti = ti+1 - ti-1
derivative() {
i=0

declare -a col
while read col[$i]
do
  i=$((i+1))
done < $1

for n in ${0..$i}:
do
  if [[ $n -eq 0 ]];
  then
    col[$n]=${col[1]}
  elif [[ $n -eq $i ]];
  then
    col[$n]=${col[$n-1]}
  else
    col[$n]=`LC_ALL=en_GB awk "BEGIN {printf \"%.12f\", ${col[$n+1]} - ${col[$n-1]}"`
  fi;
done;
}


# compute the first derivative of the WM and CSF EigTC
for tissue in WM CSF; do

    ntp=`cat ${WM_CSF_conf_dir}/${tissue}_1EigTC | wc -l`
    fslascii2img ${WM_CSF_conf_dir}/${tissue}_1EigTC \
                 ${ntp} 1 1 1   1 1 1   1 \
                 ${WM_CSF_conf_dir}/${tissue}_1EigTC.nii.gz

    fslmaths ${WM_CSF_conf_dir}/${tissue}_1EigTC.nii.gz \
             -kernel file ${f1_kernel} \
             -fmeanu ${WM_CSF_conf_dir}/${tissue}_1EigTC_f1.nii.gz

    fsl2ascii ${WM_CSF_conf_dir}/${tissue}_1EigTC_f1.nii.gz \
              ${WM_CSF_conf_dir}/${tissue}_1EigTC_f1_linevector

    # this line is just to prevent concatenation with a previously created file
    rm ${WM_CSF_conf_dir}/${tissue}_1EigTC_f1
    # the following is just to transpose the row vector to a column vector
    for j in `cat ${WM_CSF_conf_dir}/${tissue}_1EigTC_f1_linevector*`; do
        echo ${j} >> ${WM_CSF_conf_dir}/${tissue}_1EigTC_f1
    done

done

rm ${WM_CSF_conf_dir}/*0000*
rm ${WM_CSF_conf_dir}/*.nii.gz




# Motion parameters and their first derivative
mot=${bd}/preproc.feat/mc/prefiltered_func_data_mcf.par

targetdir=${bd}/preproc.feat/mc_conf

rm -rf ${targetdir}
mkdir ${targetdir}

# This separates the 6 columns of the motion parameters, 
# and writes them to a text file
for ((i=1;i<=6;i++)); do
    cat ${mot} | awk -v row=${i} '{print $row}' > ${targetdir}/Tmot_${i}
done  


# Compute the first derivative of the motion parameters
for ((i=1;i<=6;i++)); do

    ntp=`cat ${targetdir}/Tmot_${i} | wc -l`
    fslascii2img ${targetdir}/Tmot_${i} \
                 ${ntp} 1 1 1   1 1 1   1 \
                 ${targetdir}/Tmot_${i}.nii.gz

    fslmaths ${targetdir}/Tmot_${i}.nii.gz \
             -kernel file ${f1_kernel} \
             -fmeanu ${targetdir}/Tmot_${i}_f1.nii.gz

    fsl2ascii ${targetdir}/Tmot_${i}_f1.nii.gz \
              ${targetdir}/Tmot_${i}_f1_linevector

    # to prevent concatenation
    rm ${targetdir}/Tmot_${i}_f1
    # transpose
    for j in `cat ${targetdir}/Tmot_${i}_f1_linevector*`; do 
        echo ${j} >> ${targetdir}/Tmot_${i}_f1
    done

done

rm ${targetdir}/*0000*
rm ${targetdir}/*.nii.gz


# Write the nuisance matrix to a text file, and perform the regression
rm -rf ${bd}/RS_denoise
mkdir ${bd}/RS_denoise

paste -d "\t" \
      ${bd}/preproc.feat/mc_conf/Tmot_1 \
      ${bd}/preproc.feat/mc_conf/Tmot_1_f1 \
      ${bd}/preproc.feat/mc_conf/Tmot_2 \
      ${bd}/preproc.feat/mc_conf/Tmot_2_f1 \
      ${bd}/preproc.feat/mc_conf/Tmot_3 \
      ${bd}/preproc.feat/mc_conf/Tmot_3_f1 \
      ${bd}/preproc.feat/mc_conf/Tmot_4 \
      ${bd}/preproc.feat/mc_conf/Tmot_4_f1 \
      ${bd}/preproc.feat/mc_conf/Tmot_5 \
      ${bd}/preproc.feat/mc_conf/Tmot_5_f1 \
      ${bd}/preproc.feat/mc_conf/Tmot_6 \
      ${bd}/preproc.feat/mc_conf/Tmot_6_f1 \
      ${bd}/preproc.feat/WM_CSF_conf/CSF_1EigTC \
      ${bd}/preproc.feat/WM_CSF_conf/CSF_1EigTC_f1 \
      ${bd}/preproc.feat/WM_CSF_conf/WM_1EigTC \
      ${bd}/preproc.feat/WM_CSF_conf/WM_1EigTC_f1 \
      > ${bd}/RS_denoise/nuisance_mat_18 



# Run ICA AROMA (~15 min)
# We first need to create a betted version of the example_func
bet2 ${bd}/preproc.feat/reg/example_func \
     ${bd}/preproc.feat/reg/example_func_betted_4_AROMA -m

immv ${bd}/preproc.feat/reg/example_func_betted_4_AROMA_mask ${bd}/preproc.feat/AROMask

#We need to detect if python is installed, if not we can skip this part
tt=`which truc 2>&1`

if [[ $tt =~ which.* ]]; then
  echo "############### WARNING ############# \n Python can't be found on your system \
  so ICA_AROMA cannot be used"; 
else 
  python2.7 ${AROMAdir}/ICA_AROMA.py \
          -in ${ffdata} \
          -out ${bd}/preproc.feat/AROMATISED \
          -mc ${bd}/preproc.feat/mc/prefiltered_func_data_mcf.par \
          -affmat ${bd}/preproc.feat/reg/example_func2standard.mat \
          -m ${bd}/preproc.feat/AROMask.nii.gz

fi;
RS_aromatised=`ls ${bd}/preproc.feat/AROMATISED/denoised_*.nii.gz`


# Regress out the estimated nuisance parameters
fsl_glm -i ${RS_aromatised} \
        -d ${bd}/RS_denoise/nuisance_mat_18 \
        --out_res=${bd}/RS_denoise/RS_clean.nii.gz \
        --out_t=${bd}/RS_denoise/motion_fit.nii.gz


# The following is just for control: we can appreciate that the model fit of 
# the motion parameters higly decreases if we use the non-aromatised data
# fsl_glm -i ${ffdata} \
#         -d ${bd}/RS_denoise/nuisance_mat_18 \
#         --out_t=${bd}/RS_denoise/motion_fit_NO_AROMA.nii.gz





# do the bandpass filtering
#
# to calculate the required sigma values in volumes, to give to fslmaths, use:
# 1. get the period in seconds for the frequency of interest, e.g. for 0.08
#    1 / 0.08 = 12.5
# 2. divide the results by the TR to get it in terms of TRs, e.g. for TR=2.2	
#    12.5 / 2.2 = 5.68
# 3. divide again by two to get the sigma
#    5.68 / 2 = 2.84
# 
# So the general formula is 1/(2*f*TR)

HP=`echo "scale=5; 1/(2*0.009*${TR})" | bc`  # HP for 0.009 Hz
LP=`echo "scale=5; 1/(2*0.08*${TR})" | bc`   # LP for 0.08 Hz


fslmaths ${bd}/RS_denoise/RS_clean.nii.gz \
         -bptf ${HP} ${LP} \
         ${bd}/RS_denoise/RS_clean_bptf.nii.gz



























fslmaths ${bd}/RS/${subj}_RS ${bd}/RS/prefiltered_func_data -odt float

# perform MCFLIRT (~40 sec for 180 vols)
time mcflirt -in ${bd}/RS/prefiltered_func_data \
        -out ${bd}/RS/prefiltered_func_data_mcf \
        -plots


/bin/mkdir -p mc 
/bin/mv -f prefiltered_func_data_mcf.mat prefiltered_func_data_mcf.par prefiltered_func_data_mcf_abs.rms prefiltered_func_data_mcf_abs_mean.rms prefiltered_func_data_mcf_rel.rms prefiltered_func_data_mcf_rel_mean.rms mc




bd=/home/leonardo/000_lavori/ABIDE_DATA_CLEANING

T1dir=/home/leonardo/000_lavori/ABIDE_DATA_CLEANING/T1

RSdir=/home/leonardo/000_lavori/ABIDE_DUALREG/raw_MNI

motdir=/home/leonardo/000_lavori/ABIDE_DATA_CLEANING/motion_parameter


subj=$1

#subj=0051199


# First remove motion parameters: we remove them now, since it's not meaningful to bptf them
# and at the same time, if we remove them after bptf of the data, they will introduce
# high-frequency fluctuations

# first add a column of 175 ones to the motion parameters
paste ${bd}/motion_parameters/${subj}_prefiltered_func_data_mcf.par \
      ${bd}/ones175 \
    > ${bd}/T1/${subj}_motpar_ones


fsl_glm -i ${RSdir}/${subj}_filtered_func_data_MNI.nii.gz \
        -d ${bd}/T1/${subj}_motpar_ones \
        --out_res=${bd}/RS_MNI_clean/${subj}_filtered_func_data_MNI_rmmot

# clean up
rm ${bd}/T1/${subj}_motpar_ones

# do the bandpass filtering
#
# to calculate the required sigma values in volumes, to give to fslmaths, use:
# 1. get the period in seconds for the frequency of interest, e.g. for 0.08
#    1 / 0.08 = 12.5
# 2. divide the results by the TR to get it in terms of TRs, e.g. for TR=2	
#    12.5 / 2.2 = 5.68
# 3. divide again by two to get the sigma
#    5.68 / 2 = 2.84
# 
# So the general formula is 1/(2*f*TR)
#
# We calculate these values in matlab, since different subjects have different TR
# and produce a file bptf_sigma_359 which has 3 columns: SUB_ID, HP_sigma, LP_sigma
#
# Then we grep and awk bptf_sigma_359 and replace the values here to do the bptf for
# the single subject

# HP sigma for 0.009 Hz
HP=`cat bptf_sigma_359 | grep ${subj} | awk -F, '{print $2}'`

# LP sigma for 0.08 Hz
LP=`cat bptf_sigma_359 | grep ${subj} | awk -F, '{print $3}'`


fslmaths ${bd}/RS_MNI_clean/${subj}_filtered_func_data_MNI_rmmot \
         -bptf ${HP} ${LP} \
         ${bd}/RS_MNI_clean/${subj}_filtered_func_data_MNI_rmmot_bptf.nii.gz



# bet
bet2 ${bd}/T1/${subj}_T1.nii.gz ${bd}/T1/${subj}_brain

# register T1 to MNI 4mm
flirt -in ${bd}/T1/${subj}_brain.nii.gz \
      -ref  ${bd}/MNI152_T1_4mm_brain \
      -out  ${bd}/T1/${subj}_brain_MNI4mm.nii.gz \
      -omat ${bd}/T1/${subj}_brain_MNI4mm.mat \
      -bins 256 -cost corratio \
      -searchrx -90 90 -searchry \
      -90 90 -searchrz -90 90 -dof 12  -interp trilinear


# FAST
fast -t 1 -n 3 -H 0.1 -I 4 -l 20.0 \
     -o ${bd}/T1/${subj}_brain_MNI4mm.nii.gz \
     ${bd}/T1/${subj}_brain_MNI4mm.nii.gz


# clean up
rm ${bd}/T1/${subj}_brain_MNI4mm_mixeltype.nii.gz 
rm ${bd}/T1/${subj}_brain_MNI4mm_pveseg.nii.gz
rm ${bd}/T1/${subj}_brain_MNI4mm_seg.nii.gz
rm ${bd}/T1/${subj}_brain_MNI4mm.mat


# threshold the pve (0.8 is taken from Biswal2010)
fslmaths ${bd}/T1/${subj}_brain_MNI4mm_pve_0.nii.gz -thr 0.8 -bin ${bd}/T1/${subj}_CSF_thr08_bin.nii.gz 
fslmaths ${bd}/T1/${subj}_brain_MNI4mm_pve_2.nii.gz -thr 0.8 -bin ${bd}/T1/${subj}_WM_thr08_bin.nii.gz 


# extract EigTC
# CSF
fslmeants -i ${bd}/RS_MNI_clean/${subj}_filtered_func_data_MNI_rmmot_bptf.nii.gz \
          -m ${bd}/T1/${subj}_CSF_thr08_bin.nii.gz --eig -o ${bd}/T1/${subj}_EigTC_CSF

# WM
fslmeants -i ${bd}/RS_MNI_clean/${subj}_filtered_func_data_MNI_rmmot_bptf.nii.gz \
          -m ${bd}/T1/${subj}_WM_thr08_bin.nii.gz --eig -o ${bd}/T1/${subj}_EigTC_WM

# GLOBAL
fslmaths ${bd}/T1/${subj}_brain_MNI4mm.nii.gz \
         -div ${bd}/T1/${subj}_brain_MNI4mm.nii.gz \
         ${bd}/T1/${subj}_brain_MNI4mm_mask.nii.gz 

fslmeants -i ${bd}/RS_MNI_clean/${subj}_filtered_func_data_MNI_rmmot_bptf.nii.gz \
          -m ${bd}/T1/${subj}_brain_MNI4mm_mask.nii.gz --eig -o ${bd}/T1/${subj}_EigTC_GLOBAL


# paste into a matrix and add 175 ones
paste ${bd}/T1/${subj}_EigTC_CSF \
      ${bd}/T1/${subj}_EigTC_WM \
      ${bd}/T1/${subj}_EigTC_GLOBAL \
      ${bd}/ones175 \
    > ${bd}/T1/${subj}_EigTC_CONFOUNDS


# fslglm to get the residuals
fsl_glm -i ${bd}/RS_MNI_clean/${subj}_filtered_func_data_MNI_rmmot_bptf.nii.gz \
        -d ${bd}/T1/${subj}_EigTC_CONFOUNDS \
        --out_res=${bd}/RS_MNI_clean/${subj}_filtered_func_data_MNI_rmmot_bptf_clean.nii.gz


# clean up
rm ${bd}/RS_MNI_clean/${subj}_filtered_func_data_MNI_rmmot.nii.gz
rm ${bd}/RS_MNI_clean/${subj}_filtered_func_data_MNI_rmmot_bptf.nii.gz
rm ${bd}/T1/${subj}_EigTC_CSF
rm ${bd}/T1/${subj}_EigTC_WM
rm ${bd}/T1/${subj}_EigTC_GLOBAL
rm ${bd}/T1/${subj}_EigTC_CONFOUNDS