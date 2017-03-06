#! /bin/bash
# AnaCOM2 - Serge Kinkingnéhun & Emmanuelle Volle & Michel Thiebaut de Schotten
# & Chris Foulon
[ $# -lt 9 ] && { echo 'Usage $0 :
   $1:    csvFile
   $2:    LesionFolder
   $3:    ResultFolder
   $4:    threshold
   $5:    controlScores
   $6:    test (Mann-Whitney, t-test, Kolmogorov-Smirnov)
   $7:    keepTmp
   $8:    detZero
   $9:    nbvox
   ${10}: ph_mode (co_deco, deco_ctr, co_ctr, classic)'; exit 1; }

# Those lines are the handling of the script's trace and errors
# Traces and errors will be stored in $3/logAnacom.txt
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

# We calculate the value that you need to add to your score to avoid zeros AND
# negative values
subZero=0
if [[ $8 == "true" ]];
then
  stillZero=$8
  valMu=$5 #In case of mean control value
  while [[ $stillZero == "true" ]]; #While we have a zero in data
  do
    subZero=$((subZero + 1));
    stillZero="false"
    #If there are zeros, we will add 1 to all scores until they are all gone
    for i in ${!sco[@]}; #for all scores
    do
      #We add 1 to the value of the cell
      sco[$i]=`LC_ALL=en_GB awk "BEGIN {printf \"%.6f\", ${sco[$i]} + 1}"`
      if [[ ${sco[$i]} == "0.000000" ]]; #if the new value is equal to 0
      then
	       stillZero="true"
         #So we generated a new zero value and we need to make another loop
      fi;
    done;
    if [[ $5 =~ ^[0-9]+\.[0-9]+|[0-9]+$ ]];
    then
      valMu=`LC_ALL=en_GB awk "BEGIN {printf \"%.6f\", $valMu + 1}"`
      if [[ $valMu == "0.000000" ]]; #if the new value is equal to 0
      then
	       stillZero="true"
         #So we generated a new zero value and we need to make another loop
      fi;
    else
      for i in ${!full[@]}; #for all scores
      do
	#We add 1 to the value of the cell
	full[$i]=`LC_ALL=en_GB awk "BEGIN {printf \"%.6f\", ${full[$i]} + 1}"`
	if [[ ${full[$i]} == "0.000000" ]]; #if the new value is equal to 0
	then
	  stillZero="true" #So we generated a new zero value and we need to make another loop
	fi;
      done;
    fi;
  done;
fi;
#So here we have removed ALL zeros of every scores we have !

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
    #Here we calculate the number of voxels contained by the cluster
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
  #Be careful, here, in clusters, we have the added scores of patients
  #ADDED to the standard deviation. For now we don't use this value but it could
  #make errors if we use it. (Solution is to substract each cluster by maskedStd)
done;

echo "#"
#Here we want to find which patients belong to clusters
#For that we try to overlap lesions with clusters
for ((i=0; i<$numclu; i++));
do
  index=0;
  score="";
  patient="";
  for p in ${pat[*]};
  do
    fslmaths $cluD/cluster$i -mas $2/$p $tmp/tmpMask${i}_${p};
    #If there is an overlap between cluster and lesion we write the name and
    #the score else we remove the file
    if [ `fslstats $tmp/tmpMask${i}_${p} -V | awk '{ print $1 }'` == 0 ];
    then
      co_scores="$score${originalSco[$index]},"
      rm -rf $tmp/tmpMask${i}_${p}.*;
    else
      patient="$patient$p,"
      score="$score${originalSco[$index]},"
    fi;
    index=$((index + 1));
  done;
  #We remove the last comma of strings and we store values in files
  echo -n "${patient:0:${#patient}-1}" >> $tmp/cluster${i}pat.txt
  echo -n "${score:0:${#score}-1}" >> $tmp/cluster${i}sco.txt
  echo -n "${score:0:${#co_score}-1}" >> $tmp/cluster${i}co_perf.txt
done;
echo "#"


# Just define the test we will compute
if [[ $6 == "Mann-Whitney" ]];
then
  testname="wilcox.test";
  testvalue="W";
  test_number=2
elif [[ $6 == "t-test" ]];
then
  testname="t.test";
  testvalue="t";
  test_number=1
elif [[ $6 == "Kolmogorov-Smirnov" ]];
then
  testname="ks.test"
  testvalue="D";
  test_number=3
else
  echo "This test is unknown"
  exit(1)
fi;

# We can use 4 comparison modes : classic(only post_hoc), co_deco, co_ctr,
# deco_ctr
if [[ ${10} == "1" ]];
then
  ph_mode=1
elif [[ ${10} == "2" ]];
then
  ph_mode=2
elif [[ ${10} == "3" ]];
then
  ph_mode=3
elif [[ ${10} == "4" ]];
then
  ph_mode=4
else
  echo "This ph_mode is unknown"
  exit(1)
fi;


# It is the function that will handle the result of the statistical test
Rscript stats_proper.r $tmp $5 $ph_mode $test_number $3


une carte avec kruskal significatif et une avec les post_hoc significatifs
et aussi leur carte de toutes les pval pour les deux
Et un mask binaire pour chaque cluster (avant les tests)

# We need to extract the pvalues from the results of the R script
#### READING the csv file containing patient name and their score ####


En fait ce que je dois faire : Dans tous les cas je récupère les valeurs dans
kruskal_pvalues.csv et je crée les clusters binaires ET les deux cartes :
tous les clusters avec leur pvalues du KW ET celle de tous les clusters significatifs
après le kruskal.

Ensuite, SI le mode only kruskal est séléctionné OU que la carte des clusters
significatifs du kruskal est vide je crée les deux cartes (Tous et ceux qui sont
significatifs) pour les tests post hoc.


#Here we fill arrays with the columns of the csv file, IFS define separators
kw_csv="$3/kruskal_pvalues.csv"
kw_res="$3/kruskal_clusters.nii.gz"
kw_corr="$3/kruskal_holm_clusters.nii.gz"
#Counter for adding value in cells
kw_i=0
# cluster names
declare -a kw_clu
# pvalues of the KW tests
declare -a kw_pval
# holm correction of the KW tests
declare -a kw_holm

# Be careful, the first index of values is 1, 0 is the index of the column name
while IFS=, read kw_clu[$kw_i] useless kw_pval[$kw_i] kw_holm[$kw_i]
do
  kw_i=$((kw_i+1))
done < $kw_csv

# Here we binarize the clusters and we create the maps of pvalues for the KW
for n in ${#kw_clu[#]};
do
  fslmaths $cluD/${kw_clu[$n]} -bin $cluD/${kw_clu[$n]}
  fslmaths $cluD/${kw_clu[$n]} -add $kw_res $kw_res
  if [ `awk "BEGIN { print (${kw_holm[$n]} < 0.05)}"` == 1 ];
  then
    fslmaths $cluD/${kw_clu[$n]} -add $kw_corr $kw_corr
  fi;
done;
# if [ `awk "BEGIN { print (${bonf[$index]} > 1)}"` == 1 ];
# Now we create the overlap of all clusters with their pvalue in the KW


ph_csv="$3/clusters.csv"
ph_res="$3/cluters.nii.gz"
ph_corr="$3/clusters_holm.nii.gz"
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

# Be careful, the first index of values is 1, 0 is the index of the column name
while IFS=, read ph_clu[$ph_i] useless ph_kw_pval[$ph_i] ph_kw_holm[$ph_i]\
 nb_disco[$ph_i] ph_pval[$ph_i] ph_osef ph_holm[$ph_i];
do
  kw_i=$((kw_i+1))
done < $ph_csv

for n in ${#ph_clu[#]};
do
  fslmaths $cluD/${ph_clu[$n]} -add $ph_res $ph_res
  if [ `awk "BEGIN { print (${ph_holm[$n]} < 0.05)}"` == 1 ];
  then
    fslmaths $cluD/${ph_clu[$n]} -add $ph_corr $ph_corr
  fi;
done;

# CLEANING

if [[ -e $saveTmp ]];
then
  mv $cluD $saveTmp;
  mv $tmp/maskedStd.* $saveTmp;
  mv $map $saveTmp;
else
  mv $cluD $tmp/;
fi;
# If you forget to check saveTmp, you can recover tmp files if you don't
# launch anacom2 again

# rm -rf $tmp
