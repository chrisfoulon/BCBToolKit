#! /bin/bash
#AnaCOM2 - Leonardo Cerliani & Michel Thiebaut de Schotten & Chris Foulon 
[ $# -lt 3 ] && { echo "Usage : $0 T1Folder RSFolder resultsFolder "; exit 1; }

#Those lines are the handling of the script's trace and errors
#Traces and errors will be stored in $3/logAnacom.txt
export PS4='+(${LINENO})'
echo -n "" > $3/logAnacom.txt
exec 2>> $3/logAnacom.txt
set -x

path=${PWD}/Tools

extra=$path/extraFiles/restingState
ica=$path/binaries/ICA-AROMA-master

tmp=$path/tmp/tmpResting

mkdir -p $tmp

# lib=$path/libraries/lib
# bin=$path/binaries/bin
# export FSLDIR=$path/binaries
# #This line prevent missing of the bc binary for ANTs
# export PATH=$PATH:$path/binaries/bin
# 
# export LD_LIBRARY_PATH=$lib
# export FSLLOCKDIR=""
# export FSLMACHINELIST=""
# export FSLMULTIFILEQUIT="TRUE"
# export FSLOUTPUTTYPE="NIFTI_GZ"
# export FSLREMOTECALL="" 
# #IMPORTANT
# export FSLTCLSH=$bin/fsltclsh





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
# NB: the script determines the TR and the number of time points using the fslinfo, 
#     therefore it is assumed that these information are correctly reported in the 
#     header of the original 4D RS.nii.gz file

##We will use two folders in parameters : one for patients' T1 and one for patients' resting state

#Static variables
T1Folder=$1 #folder of T1 images
RSFolder=$2 #folder of Resting States

res=$3

#The base of fsf file we'll use to make custom templates
design_TEMPLATE=$extra/design_preproc_TEMPLATE.fsf

f1_kernel=$extra/f1_kernel.nii.gz

MNI2mm=$extras/MNI152_T1_2mm_brain


max3() {
  max=$1
  if [ `awk "BEGIN { print ($max > $2) }"` ];
  then
    if [ `awk "BEGIN { print ($max > $3) }"` ];
    then
      #$1 > all
      return $max;
    else
      #$3 > all
      max=$3
      return $max;
    fi;
  else
    max=$2
    if [ `awk "BEGIN { print ($max > $3) }"` ];
    then
      #$2 > all
      return $max;
    else
      #$3 > all
      max=$3
      return $max;
    fi;
  fi;
}


#Param : the T1 image 
findSmoothing() {
  pxd1=`fslinfo $1 | grep ^pixdim1 | awk '{print $2}'`  
  pxd2=`fslinfo $1 | grep ^pixdim2 | awk '{print $2}'`  
  pxd3=`fslinfo $1 | grep ^pixdim3 | awk '{print $2}'` 
  
  max=`max3 $pxd1 $pxd2 $pxd3`
  return `awk "BEGIN { print $max*1.5 }"`
}


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

  for ((n=0; n<=$i; n++));
  do
    if [[ $n -eq 0 ]];
    then
      col[$n]=${col[1]}
    elif [[ $n -eq $i ]];
    then
      col[$n]=${col[$n-1]}
    else
      col[$n]=`LC_ALL=en_GB awk "BEGIN {printf \"%.12f\", ${col[$n+1]} - ${col[$n-1]}}"`
    fi;
  done;
  for c in $col[@]};
  do
    echo $c >> $1_fi
  done;
}




#Param : $1 = patient's name
preproc() {

#We will create a separate folder for each patient
subj=$1
resPat=${res}/${subj}
T1=$T1Folder/$subj
RS=$RSFolder/$subj
mkdir $resPat
#I am not sure but I think the TR is the value of pixdim[4]
TR=`fslinfo $RS | grep ^pixdim4 | awk '{print $2}'`  
# necessary for estimating the sigma of the bandpass temporal filters


customFSF=${resPat}/design_preproc_${subj}.fsf

# in mm
#OLD smoothing_kernel=5
smoothing_kernel=`findSmoothing ${T1}`
slice_time_correction=1
# Slice timing correction
# 0 : None
# 1 : Regular up (0, 1, 2, 3, ...)
# 2 : Regular down
# 3 : Use slice order file
# 4 : Use slice timings file
# 5 : Interleaved (0, 2, 4 ... 1, 3, 5 ... )

###############################################################################
# END OF PARAMETERS TO BE MODIFIED BY THE USER



# for the fsf template - automatically imported
FEATNUMBERTIMEPOINTS=`fslinfo ${RS} | grep ^dim4 | awk '{print $2}'`

FEATT1RESTORE=${resPat}/${subj}_T1_restore_brain


# do the sed on the design_preproc_TEMPLATE.fsf
# in order to create the design to perform the 
# preprocessing on the 4D RS data
sed -e "s@FEATBASEDIR@${resPat}@g" \
    -e "s@FEATTR@${TR}@g" \
    -e "s@FEATNUMBERTIMEPOINTS@${FEATNUMBERTIMEPOINTS}@g" \
    -e "s@FEATSLICETIME@${slice_time_correction}@g" \
    -e "s@FEATSMOOTHING@${smoothing_kernel}@g" \
    -e "s@FEATMNI@${MNI2mm}@g" \
    -e "s@FEATT1RESTORE@${FEATT1RESTORE}@g" \
    -e "s@FEAT4DRSDATA@${RS}@g" \
       ${design_TEMPLATE} > ${customFSF}




# FAST for field bias estimation ONLY. This is functional to obtaining a better
# skull stripping, carried out in the subsequent BET2
fast -t 1 -n 3 -H 0.1 -I 4 -l 20.0 --nopve -B \
     -o ${tmp}/${subj}_T1_restore ${T1}

rm ${tmp}/${subj}_T1_restore_seg



# BET2
bet2 ${tmp}/${subj}_T1_restore $FEATT1RESTORE -m


# FAST for estimating the location of WM and CSF, whose time course will be used
# later for nuisance regression
mkdir -p $resPat/fast
fast -t 1 -n 3 -H 0.1 -I 4 -l 20.0 -o $resPat/fast/${subj}_T1_restore_brain \
                                      $FEATT1RESTORE

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
feat ${customFSF}





# Estimation of WM and CSF time courses
# (1) Register the T1_restore_brain to the EPI using the previously estimated transformation in 
#     ${featdir}/reg/highres2example_func.mat. 
# (2) Segment the T1_restore_brain_epispace and take the p=0.9 of WM (pve_2) and CSF (pve_0)
# (3) Use them to extract the mean time course in the filtered_func_data
# (4) Compute their first derivative
WM_CSF_conf_dir=${resPat}/WM_CSF_conf
mkdir ${WM_CSF_conf_dir}
#If I understand well, this will be created by feat
featdir=${resPat}.feat

flirt -in $FEATT1RESTORE \
      -applyxfm -init $featdir/reg/highres2example_func.mat \
      -out ${WM_CSF_conf_dir}/T1_restore_brain_epispace \
      -paddingsize 0.0 -interp trilinear \
      -ref $featdir/example_func.nii.gz

T1_epi_seg=${WM_CSF_conf_dir}/fast_T1epispace
mkdir ${T1_epi_seg}
fast -t 1 -n 3 -H 0.1 -I 4 -l 20.0 \
     -o ${T1_epi_seg}/T1_restore_brain_epispace \
        ${WM_CSF_conf_dir}/T1_restore_brain_epispace

ffdata=$featdir/filtered_func_data.nii.gz

# threshold WM (pve_2) and CSF (pve_0) pve to 0.9, and extract the eigTC from the
# filtered_func_data
fslmaths ${T1_epi_seg}/T1_restore_brain_epispace_pve_0.nii.gz \
         -thr 0.9 -bin ${T1_epi_seg}/CSF_thr09

fslmeants -i ${ffdata} -m ${T1_epi_seg}/CSF_thr09 --eig -v -o ${featdir}/WM_CSF_conf/CSF_1EigTC

fslmaths ${T1_epi_seg}/T1_restore_brain_epispace_pve_2.nii.gz \
         -thr 0.9 ${T1_epi_seg}/WM_thr09

fslmeants -i ${ffdata} -m ${T1_epi_seg}/WM_thr09 --eig -v -o ${featdir}/WM_CSF_conf/WM_1EigTC

derivative ${featdir}/WM_CSF_conf/CSF_1EigTC
derivative ${featdir}/WM_CSF_conf/WM_1EigTC

# Motion parameters and their first derivative
mot=$featdir/mc/prefiltered_func_data_mcf.par

targetdir=$featdir/mc_conf

rm -rf ${targetdir}
mkdir ${targetdir}

# This separates the 6 columns of the motion parameters, 
# and writes them to a text file
for ((i=1;i<=6;i++)); do
    cat ${mot} | awk -v row=${i} '{print $row}' > ${targetdir}/Tmot_${i}
    derivative ${targetdir}/Tmot_${i}
done  





# Write the nuisance matrix to a text file, and perform the regression
rm -rf ${resPat}/RS_denoise
mkdir ${resPat}/RS_denoise

nuisMat=${resPat}/RS_denoise/nuisance_mat_18
paste -d "\t" \
      $featdir/mc_conf/Tmot_1 \
      ${featdir}/mc_conf/Tmot_1_f1 \
      ${featdir}/mc_conf/Tmot_2 \
      ${featdir}/mc_conf/Tmot_2_f1 \
      ${featdir}/mc_conf/Tmot_3 \
      ${featdir}/mc_conf/Tmot_3_f1 \
      ${featdir}/mc_conf/Tmot_4 \
      ${featdir}/mc_conf/Tmot_4_f1 \
      ${featdir}/mc_conf/Tmot_5 \
      ${featdir}/mc_conf/Tmot_5_f1 \
      ${featdir}/mc_conf/Tmot_6 \
      ${featdir}/mc_conf/Tmot_6_f1 \
      ${featdir}/WM_CSF_conf/CSF_1EigTC \
      ${featdir}/WM_CSF_conf/CSF_1EigTC_f1 \
      ${featdir}/WM_CSF_conf/WM_1EigTC \
      ${featdir}/WM_CSF_conf/WM_1EigTC_f1 \
      > ${nuisMat}



# Run ICA AROMA (~15 min)
# We first need to create a betted version of the example_func
bet2 ${featdir}/reg/example_func \
     ${featdir}/reg/example_func_betted_4_AROMA -m

immv ${featdir}/reg/example_func_betted_4_AROMA_mask ${featdir}/AROMask

#We need to detect if python is installed, if not we can skip this part
tt=`which python2.7 2>&1`

if [[ $tt =~ which.* ]]; then
  echo "############### WARNING ############# \n Python 2.7 can't be found on your system \
  so ICA_AROMA cannot be used"; 
else 
  python2.7 ${ica}/ICA_AROMA.py \
          -in ${ffdata} \
          -out ${featdir}/AROMATISED \
          -mc ${featdir}/mc/prefiltered_func_data_mcf.par \
          -affmat ${featdir}/reg/example_func2standard.mat \
          -m ${featdir}/AROMask.nii.gz

fi;

RS_aromatised=`ls ${featdir}/AROMATISED/denoised_*.nii.gz`

rsClean=${resPat}/RS_denoise/RS_clean.nii.gz
# Regress out the estimated nuisance parameters
fsl_glm -i ${RS_aromatised} \
        -d $nuisMat \
        --out_res=${RSClean} \
        --out_t=${resPat}/RS_denoise/motion_fit.nii.gz


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


fslmaths $rsClean \
         -bptf ${HP} ${LP} \
         ${resPat}/RS_denoise/RS_clean_bptf.nii.gz



prefiltData=${resPat}/prefiltered_func_data
fslmaths ${RS} $prefiltData -odt float

# perform MCFLIRT (~40 sec for 180 vols)
time mcflirt -in $prefiltData \
        -out ${resPat}/prefiltered_func_data_mcf \
        -plots


mkdir -p ${resPat}/mc 
mv -f ${resPat}/prefiltered_func_data_mcf.mat ${resPat}/prefiltered_func_data_mcf.par ${resPat}/prefiltered_func_data_mcf_abs.rms ${resPat}/prefiltered_func_data_mcf_abs_mean.rms ${resPat}/prefiltered_func_data_mcf_rel.rms ${resPat}/prefiltered_func_data_mcf_rel_mean.rms ${resPat}/mc

}