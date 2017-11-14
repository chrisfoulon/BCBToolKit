#! /bin/bash
# AnaCOM2 - Serge Kinkingnéhun & Emmanuelle Volle & Michel Thiebaut de Schotten
# & Chris Foulon
[ $# -lt 9 ] && { echo 'Usage $0 :
   $1:    csvFile
   $2:    LesionFolder
   $3:    ResultFolder
   $4:    threshold
   $5:    controlScores
   $6:    test (Mann-Whitney, t-test, Kolmogorov-Smirnov, Kruskal-Wallis)
   $7:    keepTmp
   $8:    detZero
   $9:    nbvox
   ${10}: ph_mode (no post-hoc, co_deco, deco_ctr, co_ctr)'; exit 1; }

# Those lines are the handling of the script's trace and errors
# Traces and errors will be stored in $3/logAnacom.txt
export PS4='+(${LINENO})'
echo -n "" > $3/logAnacom.txt
exec 2>> $3/logAnacom.txt
set -x

PATH=$( echo $PATH | tr ":" "\n" | grep  -v "fsl" | tr -s "\n" ":" | sed 's/:$//')
LD_LIBRARY_PATH=$( echo $LD_LIBRARY_PATH | tr ":" "\n" | grep  -v "fsl" | tr -s "\n" ":" | sed 's/:$//')

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

tmp=$path/tmp/tmpAnacom
if [[ -e $tmp ]];
then
  rm -rf $tmp;
fi;
mkdir -p $tmp

if [[ $7 == "true" ]];
then
  saveTmp=$3/anacomTemporaryFiles
  if [[ -e $saveTmp ]];
  then
    rm -rf $saveTmp;
  fi;

  mkdir -p $saveTmp
fi;


#For controls, we can have scores for each control or just the mean value
#(just in ttest case).

#### READING the csv file containing patient name and their score ####
#Counter for adding value in cells
i=0
#Here we fill arrays with the two columns of the csv file, IFS define separators

declare -a pat
declare -a sco
while IFS=, read pat[$i] sco[$i]
do
    i=$((i+1))
done < $1

#We have to manage empty lines in the csv file so we unset empty cells
for ((i=0; i < ${#pat[@]};i++));
do
  if [[ ${pat[$i]} == "" ]];
  then
    unset pat[$i];
  fi;
  if [[ ${sco[$i]} == "" ]];
  then
    unset sco[$i];
  fi;
done;

# We maybe have unset some cells of arrays so maybe some indexes
# are not valid anymore
# We will correct arrays to be sure that array cells are contiguous
tmppat=( "${pat[@]}" )
tmpsco=( "${sco[@]}" )
unset pat
unset sco
declare -a pat
declare -a sco

ii=0;
for i in ${!tmppat[@]};
do
  pat[$ii]=${tmppat[$i]};
  sco[$ii]=${tmpsco[$i]};
  ii=$((ii + 1));
done;
#We store original scores to write them correctly in txt files and in the
# cluster.csv result file
originalSco=( "${sco[@]}" )

#We need control scores, we can have a mean if we have wilcoxon or ttest
#Or a vector of scores which will be a column in a csv file
if [[ $5 =~ ^[0-9]+\.[0-9]+|[0-9]+$ ]];
then
    control="mu=$5"
else
    i=0
    declare -a contr
    while IFS=, read contr[$i]
    do
      i=$((i+1))
    done < $5

    #We have to manage empty lines in the csv file so we unset empty cells
    for ((i=0; i < ${#contr[@]};i++));
    do
      if [[ ${contr[$i]} == "" ]];
      then
	      unset contr[$i];
      fi;
    done;
    #Here we fill a new tab with contiguous cells
    cc=0
    declare -a full
    for ct in ${contr[*]};
    do
      full[$cc]=$ct
      cc=$((cc + 1))
    done;
fi

if [[ $5 =~ ^[0-9]+\.[0-9]+|[0-9]+$ ]];
then
  control="mu=$valMu"
else
  #We create a R vector with control scores
  for ((i=0; i < ${#full[@]} - 1; i++));
  do
    y="${y}${full[$i]},"
  done;
  control="c(${y}${full[${#full[@]} - 1]})"
fi;

# for i in ${!sco[@]}; do echo "Index $i : [${pat[$i]} | ${sco[$i]}]"; done;
# for i in ${!full[@]}; do echo "Index $i : [${full[$i]}]"; done;
#### BINARISATION of ROIs AND ScoredROI creation AND adding binROI in overlapROI and scoROI in overlapScores ####
num=0
oR=$tmp/overlapROI.nii.gz
oS=$tmp/overlapScores.nii.gz
#creating void overlaps one time
fslmaths $2/${pat[0]} -mul 0 $oR
fslmaths $2/${pat[0]} -mul 0 $oS
for f in ${pat[*]}
do
    #binarisation
    fslmaths $2/$f -bin $tmp/bin$f
    #scoring
    fslmaths $tmp/bin$f -mul ${sco[$num]} $tmp/sco$f
    #adding ROI
    fslmaths $tmp/bin$f -add $oR $oR
    #adding ScoredROI
    fslmaths $tmp/sco$f -add $oS $oS
    num=$((num + 1))
done
echo "#"

#### Mean Values Map ####
#We just devide overlapScores by overlapROI in meanValMap.nii.gz
fslmaths $oS -div $oR $tmp/meanValMap.nii.gz

#### Thresholding the overlapROI in mask.nii.gz ####
fslmaths $oR -thr $4 $tmp/mask.nii.gz

#### Applying the mask to meanValMap.nii.gz ####
map=$tmp/maskedMeanValMap.nii.gz
#It will be used for clustering
overMask=$tmp/maskedOverlap.nii.gz
fslmaths $tmp/meanValMap.nii.gz -mas $tmp/mask.nii.gz $map
fslmaths $tmp/overlapScores -mas $tmp/mask.nii.gz $overMask

#Now we will make a layer for each score found in maskedOverlap
#For that, we take the maximum score of the map and we cut its top
nblayer=0
max=`fslstats $overMask -R | awk '{print $2}'`;
fslmaths $overMask -thr $max $tmp/layer${nblayer}

fslmaths $overMask -sub $tmp/layer${nblayer} $tmp/eroded

volume=`fslstats $tmp/layer${nblayer} -V | awk '{ print $1 }'`
#If it is lower than the threshold $9 we remove the cluster and we will
#create another with that number at the next loop
if [[ $volume -lt $9 ]];
then
  rm -rf $tmp/layer${nblayer}.*;
else
  nblayer=$((nblayer + 1))
fi;
while [ `fslstats $tmp/eroded -V | awk '{ print $1 }'` != 0 ];
do
  max=`fslstats $tmp/eroded -R | awk '{print $2}'`;

  fslmaths $tmp/eroded -thr $max $tmp/layer${nblayer}

  fslmaths $tmp/eroded -sub $tmp/layer${nblayer} $tmp/eroded

  volume=`fslstats $tmp/layer${nblayer} -V | awk '{ print $1 }'`

  #If it is lower than the threshold $9 we remove the cluster and we will
  #create another with that number at the next loop
  if [[ $volume -lt $9 ]];
  then
    rm -rf $tmp/layer${nblayer}.*;
  else
    nblayer=$((nblayer + 1))
  fi;
done;
#erorded is now full of 0
rm -rf $tmp/eroded
echo "#"
# Here we test if layer files were created
if [ `find $tmp/layer* -maxdepth 0 -type f | wc -l` == 0 ];
then
  echo "No clusters passed the thresholds" >&2;
  exit;
fi;

#Here, we will compute the standard deviation because if, in a layer, we can
#have different area with the same score once added but not the same
#distribution of score / patient.

#We make a 4D image with scored maps
fslmerge -t $tmp/4Dscores $tmp/sco*
#We make the standard deviation
fslmaths $tmp/4Dscores -Tstd $tmp/std
#We mask std to preserve the threshold created before
fslmaths $tmp/std -mas $tmp/mask.nii.gz $tmp/maskedStd
###############################################################################
## Now we can create our clusters by adding layers and standard deviation    ##
## With that we can garantee different values in areas with different        ##
## distributions because we have different standard deviations added to      ##
## the same value (because we are in a layer)                                ##
###############################################################################
#We keep cluster's results in the result directory
cluD=$3/anacomClustersDir
if [[ -e $cluD ]];
then
  rm -rf $cluD;
fi;


mkdir -p $cluD
numclu=0
#The order of layer files is layer0, layer1, layer10, layer11, layer12 ...

for la in $tmp/layer*;
do
  # In first we mask std with the layer and we add the layer to std
  fslmaths $tmp/maskedStd -mas $la -add $la $tmp/stdlayer
  # And now we make other layers, with each different values, which will be
  # our clusters
  while [ `fslstats $tmp/stdlayer -V | awk '{ print $1 }'` != 0 ];
  do
    max=`fslstats $tmp/stdlayer -R | awk '{print $2}'`;
    fslmaths $tmp/stdlayer -thr $max $cluD/cluster${numclu};
    fslmaths $tmp/stdlayer -sub $cluD/cluster${numclu} $tmp/stdlayer;
    #Here we calculate the number of voxels contained in the cluster
    volume=`fslstats $cluD/cluster${numclu} -V | awk '{ print $1 }'`
    #If it is lower than the threshold $9 we remove the cluster and we will
    #create another with that number at the next loop
    if [[ $volume -lt $9 ]];
    then
      rm -f $cluD/cluster${numclu}.*;
    else
      numclu=$((numclu + 1));
    fi;
  done;
  #Be careful, here, in clusters, we have the sum of scores of patients
  #ADDED to the standard deviation. For now we don't use this value but it could
  #make errors if we use it.(but we could substract each cluster by maskedStd)
done;

echo "#"
#Here we want to find which patients belong to clusters
#For that we try to overlap lesions with clusters
# Attempt to improve the calculation!
# clu_compare() {
#   clu_dir=$1
#   clu_suff=$2
#   pat_dir=$3
#   declare -a pat=("${!4}")
#   tmp_dir=$5
#   declare -a arr_scores=("${!6}")
#   index=$7
#   clu_vol=`fslstats $clu_dir/cluster$clu_suff -V | awk '{ print $1 }'`
#   for p in ${!pat[@]};
#   do
#     fslmaths $clu_dir/cluster$clu_suff -mas $pat_dir/$pat[$p] $tmp_dir/tmpMask
#     ol=`fslstats $tmp/tmpMask -V | awk '{ print $1 }'`
#     if [ $ol == 0 ];
#     then
#       echo "SPARED Clu : $clu_suff, name : $pat[$p], val : ${co_perf}${arr_scores[$index]},"
#       co_perf="${co_perf}${arr_scores[$index]},"
#       imrm $tmp/tmpMask;
#     elif [ $ol == $clu_vol ];
#     then
#       echo "DISCO Clu : $i, name : $p, val : $score${originalSco[$index]},"
#       patient="$patient$p,"
#       score="$score${originalSco[$index]},"
#       imrm $tmp/tmpMask;
#     else
#   done;
# }

for ((i=0; i<$numclu; i++));
do
  index=0;
  score="";
  co_perf=""
  patient="";
  for p in ${pat[*]};
  do
    fslmaths $cluD/cluster$i -mas $2/$p $tmp/tmpMask${i}_${p};
    #If there is an overlap between cluster and lesion we write the name and
    #the score else we remove the file
    if [ `fslstats $tmp/tmpMask${i}_${p} -V | awk '{ print $1 }'` == 0 ];
    then
      echo "SPARED Clu : $i, name : $p, val : $co_perf${originalSco[$index]},"
      co_perf="$co_perf${originalSco[$index]},"
      imrm $tmp/tmpMask${i}_${p};
    else
      echo "DISCO Clu : $i, name : $p, val : $score${originalSco[$index]},"
      patient="$patient$p,"
      score="$score${originalSco[$index]},"
      imrm $tmp/tmpMask${i}_${p};
    fi;
    index=$((index + 1));
  done;
  #We remove the last comma of strings and we store values in files
  echo -n "${patient:0:${#patient}-1}" >> $tmp/cluster${i}pat.txt
  echo -n "${score:0:${#score}-1}" >> $tmp/cluster${i}sco.txt
  echo -n "${co_perf:0:${#co_perf}-1}" >> $tmp/cluster${i}co_perf.txt
done;
echo "#"

# We can use 4 comparison modes : No only post_hoc, co_deco, co_ctr,
# deco_ctr


# It is the function that will handle the result of the statistical test
Rscript $path/scripts/stats_proper.r $tmp $5 ${10} $6 $3

# We need to extract the pvalues from the results of the R script
#### READING the csv file containing patient name and their score ####

# 1 is the Kruskal-Wallis
if [[ ${6} == "1" ]];
then
  #Here we fill arrays with the columns of the csv file, IFS define separators
  kw_csv="$3/kruskal_pvalues.csv"
  kw_res="$3/kruskal_clusters.nii.gz"
  kw_corr="$3/kruskal_holm_clusters.nii.gz"
  fslmaths $map -mul 0 $kw_res
  fslmaths $map -mul 0 $kw_corr
  #Counter for adding value in cells
  kw_i=0
  # cluster names
  declare -a kw_clu
  # pvalues of the KW tests
  declare -a kw_pval
  # holm correction of the KW tests
  declare -a kw_holm
  useless=0
  # Be careful, the first index of values is 1, 0 is the index of the column name
  while IFS=, read kw_clu[$kw_i] kw_pval[$kw_i] useless kw_holm[$kw_i]
  do
    kw_i=$((kw_i+1))
  done < $kw_csv
  unset kw_clu[0]
  unset kw_pval[0]
  unset kw_holm[0]
  # Here we binarize the clusters and we create the maps of pvalues for the KW
  for n in ${!kw_clu[@]};
  do
    if [[ ${kw_clu[$n]//\"} != "" ]];
    then
      # //\" inside ${} will remove the character " from strings !
      fslmaths $cluD/${kw_clu[$n]//\"} -bin $cluD/${kw_clu[$n]//\"}
      fslmaths $cluD/${kw_clu[$n]//\"} -mul \
      `awk " BEGIN {print 1 - ${kw_pval[$n]}}"` -add $kw_res $kw_res
      # fslmaths $cluD/${kw_clu[$n]//\"} -mul $((1-${kw_pval[$n]})) \
      # -add $kw_res $kw_res
      if [ `awk "BEGIN { print (${kw_holm[$n]} < 0.05)}"` == 1 ];
      then
        fslmaths $cluD/${kw_clu[$n]//\"} -mul \
        `awk "BEGIN {print 1 - ${kw_holm[$n]}}"` -add \
        $kw_corr $kw_corr
      fi;
    fi;
  done;
fi;

ph_csv="$3/clusters.csv"

if [ ${10} != "1" ] && [ -e $ph_csv ];
then
  # Now we create the overlap of all clusters with their pvalue in the KW

  ph_res="$3/clusters.nii.gz"
  ph_corr="$3/clusters_holm.nii.gz"
  fslmaths $map -mul 0 $ph_res
  fslmaths $map -mul 0 $ph_corr
  #Counter for adding value in cells
  ph_i=0
  # cluster names
  declare -a ph_clu
  # pvalues of the KW tests
  declare -a ph_kw_pval
  # holm correction of the KW tests
  declare -a ph_kw_holm
  # Number of disconnected patients
  declare -a nb_disco
  # pval of the post_hoc tests
  declare -a ph_pval
  # holm correction of the post_hoc tests
  declare -a ph_holm
  useless=0
  ph_osef=0

  if [[ $6 == '1' ]];
  then
    # Be careful the first index of values is 1, 0 is the index of the column name
    while IFS=, read ph_clu[$ph_i] ph_kw_pval[$ph_i] useless ph_kw_holm[$ph_i]\
     nb_disco[$ph_i] ph_pval[$ph_i] ph_osef ph_holm[$ph_i];
    do
      ph_i=$((ph_i+1))
    done < $ph_csv
  else
    # Be careful the first index of values is 1, 0 is the index of the column name
    while IFS=, read ph_clu[$ph_i] nb_disco[$ph_i] ph_pval[$ph_i]\
      ph_osef ph_holm[$ph_i];
    do
      ph_i=$((ph_i+1))
    done < $ph_csv
  fi;

  unset ph_clu[0]
  unset ph_kw_pval[0]
  unset ph_kw_holm[0]
  unset nb_disco[0]
  unset ph_pval[0]
  unset ph_holm[0]

  echo ${ph_clu[@]}
  echo ${!ph_clu[@]}

  for n in ${!ph_clu[@]};
  do
    if [[ ${ph_clu[$n]//\"} != "" ]];
    then
      fslmaths $cluD/${ph_clu[$n]//\"} -mul \
      `awk "BEGIN {print 1 - ${ph_pval[$n]}}"` -add $ph_res $ph_res
      if [ `awk "BEGIN { print (${ph_holm[$n]} < 0.05)}"` == 1 ];
      then
        fslmaths $cluD/${ph_clu[$n]//\"} -mul \
        `awk "BEGIN {print 1 - ${ph_holm[$n]}}"` -add $ph_corr $ph_corr
      fi;
    fi;
  done;
fi;
# CLEANING

if [[ -e $saveTmp ]];
then
  mv $cluD $saveTmp;
  mv $tmp/maskedStd.* $saveTmp;
  mv $map $saveTmp;
else
  mv $cluD $tmp/;
fi;
echo "#"
# If you forget to check saveTmp, you can recover tmp files if you don't
# launch anacom2 again

# rm -rf $tmp
