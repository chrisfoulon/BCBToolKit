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

#Here we fill arrays with the two columns of the csv file, IFS define separators
kw_res="$3/kruskal_pvalues.csv"
#Counter for adding value in cells
kw_i=0
# cluster names
declare -a kw_clu
# pvalues of the KW tests
declare -a kw_pval
# holm correction of the KW tests
declare -a kw_holm
# Number of disconnected patients
declare -a nb_disco
# pval of the post_hoc tests
declare -a ph_pval
# holm correction of the post_hoc tests
declare -a ph_holm

useless=""
# Be careful, the first index of values is 1, 0 is the index of the column name
while IFS=, read kw_clu[$kw_i] useless kw_pval[$kw_i] kw_holm[$kw_i]\
 nb_disco[$kw_i] ph_pval[$kw_i] ph_osef ph_holm[$kw_i];
do
    kw_i=$((kw_i+1))
done < $1

# Here we just binarize the clusters
for n in ${#kw_clu[#]};
do
  fslmaths $cluD/${kw_clu[$n]} -bin $cluD/${kw_clu[$n]}
done;

# We can read clustersco files and apply statistical tests
for ((i=0; i<$numclu; i++));
do
  read text < $tmp/cluster${i}sco.txt
  x="c("$text")"
  read co_text < $tmp/cluster${i}co_perf.txt
  co_x="c("$co_text")"
  compute="myTest($testname, \"$tmp/cluster${i}pat.txt\", $co_x, $x, $control)"
  patNumber="write(length($x), \"$tmp/cluster${i}pat.txt\", append=TRUE, sep=\"\\n\");"
  #echo "print('Compute : $compute')" >> $tmp/stats.r
  echo $compute >> $tmp/stats.r
  echo $patNumber >> $tmp/stats.r
done;

#We launch the R script to compute pvalues
# $tmp/stats.r
# Here, in each score file, we have patients' names, pvalue of the test, the
# value of the test and then the number of patients.

#Give the real representation of a number that was in scientific notation
realVal() {
  nu=`echo $1 | sed 's/e-.*//g'`
  #In exp we have the exponent of $1
  exp=`printf "%s" ${1#*e-}`
  exp=`awk "BEGIN {print $exp - 1}"`
  #we compute the number of decimals : It's the number of digits of $numb
  # (so without the '.') plus the exponent minus 1 because of the notation
  # ex : 1.3e-4 == 0.00013
  nbdec=`awk "BEGIN {print ${#nu} - 1 + $exp}"`
  #Now we can write $1 without the scientific notation and without
  # precision loss
  echo `LC_ALL=en_GB awk "BEGIN {printf \"%.${nbdec}f\", ${nu}/10e${exp}}"`
}

#We declare an array to store pvalues for bonferroni-holm correction
declare -a bonf
#Creation of an empty file #ugly
fslmaths $overMask -mul 0 $3/mergedPvalClusters
for ((i=0; i<$numclu; i++));
do
  #We read the second line of every cluster*pat.txt which contain the pvalue
  pval=`sed -n 2p $tmp/cluster${i}pat.txt`

  if [[ $pval != "NaN" ]];
  then
    if [[ $pval =~ ^[0-9]+\.[0-9]+e-[0-9]+$ ]];
    then
      bonf[$i]=`realVal $pval`
    else
      bonf[$i]=$pval;
    fi;
  else
    pval=-1
  fi;
  # if pval != 0
  if [ `awk "BEGIN { print ($pval == 0)}"` == 0 ];
  then
    # We round $pval
    pval=$(LC_ALL=en_GB awk "BEGIN {printf \"%.6f\", $pval}");
    # If $pval is round to 0.000000 we set pval to 0.000001 because it means that
    # the real pval is less than 0.000001
    if [ `awk "BEGIN { print ($pval == 0)}"` == 1 ];
    then
        pval="0.000001";
    fi;
#pval=$(awk "BEGIN { if ($pval == 0) {print \"0.000001\";} else {print $pval }")
  fi;
  #We make 1 - pval for a better visualizing
  oneminuspval=$(LC_ALL=en_GB awk "BEGIN {printf \"%.6f\", 1 - $pval}");
  fslmaths $cluD/cluster${i} -bin -mul $oneminuspval $cluD/pvalcluster${i}

#   fslmaths $cluD/cluster${i} -bin $cluD/pvalcluster${i}

#   fslmaths $cluD/pvalcluster${i} -mul $pval $cluD/pvalcluster${i}
  # Creation of a file containing all clusters with pvalues. ($3/mergedPvalClusters)
  fslmaths $cluD/pvalcluster${i} -add $3/mergedPvalClusters $3/mergedPvalClusters

done;
#Here we have all pvalues (without NaN) stored in bonf indexed by cluster number
#To correct pvalues with Bonferroni-Holm method we have to sort them in ascending order
declare -a sorted;
declare -a indexes;
# Sort with -g (for floats)
# IFS=$'\n' var=($(sort -g <<<"${bonf[@]}"))
# unset IFS
set +x
var=`for i in "${bonf[@]}"; do echo "$i"; done | sort -g`
set -x
# Sort give a string so we convert it as an array in $sorted
IFS=$'\n ' read -r -a sorted <<< $var
#we make a copy of sorted to use it later
copysorted=( "${sorted[@]}" )
#We will make calculation without precision loss in the array
realcorr=( "${sorted[@]}" )

# Now we create an array to associate $sorted's values with bonf's indexes
# We destroy bonf cell by cell (sorry bro)

# We store indexes of bonf
read -r -a arrInd <<< ${!bonf[@]}
# We fill indexes with indexex of bonf sorted like in ... $sorted
for i in ${!sorted[@]};
do
  ind=0;
  while [[ ${bonf[${arrInd[$ind]}]} != ${sorted[$i]} ]];
  do
    ind=$((ind + 1));
  done;
  indexes[$i]=${arrInd[$ind]};
  unset bonf[${arrInd[$ind]}];
done;
# In fact we have not to be careful about the stability of the sort (I feared)
# The bash sort is not stable but because we unset bonf's cells
# we preserve the order and make the final sort stable
# for example if bonf[23]=0.45 and bonf[34]=0.45, in the loop we will find :
# bonf[23] == sorted[i], we remove bonf[23], at i+1 we will have again
# sorted[i+1] = 0.45, in the loop we will only find now bonf[34] == 0.45

# We make Bonferroni-Holm corrections
numb=${#sorted[@]}
for ((i=0;i<${#sorted[@]};i++));
do
  tt=${sorted[$i]};
  numdec=${#tt};
  realcorr[$i]=$(LC_ALL=en_GB awk "BEGIN {printf \"%.${numdec}f\", ${sorted[$i]}*$((numb - $i))}");
  sorted[$i]=$(LC_ALL=en_GB awk "BEGIN {printf \"%.6f\", ${sorted[$i]}*$((numb - $i))}");

  # If sorted[$i] is round to 0.000000 we set sorted[$i] to 0.000001 because it means that
  # the real sorted[$i] is less than 0.000001
if [ `awk "BEGIN { print (${sorted[$i]} == 0)}"` == 1 ];
then
sorted[$i]="0.000001";
fi;
#sorted[$i]=$(awk "BEGIN { if (${sorted[$i]} == 0) print \"0.000001\"; else print ${sorted[$i]} }")
done;
# We re-create bonf with corrected pvalues
for ((i=0;i<${#sorted[@]};i++));
do
  bonf[${indexes[$i]}]=${sorted[$i]};
done;
# We create new maps with corrected pvalues
fslmaths $overMask -mul 0 $cluD/mergedBHcorrClusters
for index in ${!bonf[@]};
do
  if [ `awk "BEGIN { print (${bonf[$index]} > 1)}"` == 1 ];
  then
    tmpmul=1
  else
    tmpmul=${bonf[$index]}
  fi;
  oneminusBH=$(LC_ALL=en_GB awk "BEGIN {printf \"%.6f\", 1 - $tmpmul}");
  fslmaths $cluD/pvalcluster${index} -bin -mul $oneminusBH $cluD/BHcorrCluster${index}
  # We fill the map with all corrected pvalues
  fslmaths $cluD/BHcorrCluster${index} -add $cluD/mergedBHcorrClusters $cluD/mergedBHcorrClusters
done;


# Bonferroni correction
fslmaths $3/mergedPvalClusters -mul $numclu $tmp/tmpbonf

fslmaths $tmp/tmpbonf -uthr 1 -bin $tmp/ubonfmask

fslmaths $tmp/tmpbonf -thr 1 -bin $tmp/bonfmask

fslmaths $tmp/tmpbonf -mas $tmp/ubonfmask -add $tmp/bonfmask $3/bonferroniClusters
echo "#"

#We create csv files to display results (One with cluster names associated
#to patient names and scores with pvalues and BHcorrected pvalues and another
#for warnings if they occurs
  ## Here we have sorted pvalues in copysorted, BHcorrected pvalues, in
  ## increasing (non-corrected) pvalues, in sorted and in indexes we have
  ## corresponding between pvalues and cluster number

##
echo "Patients, p-values, Bonferroni-holm, N, $testvalue" > $3/clusters.csv
fslmaths $3/bonferroniClusters -mul 0 $3/correctedClusters
exclude=''
for i in ${!sorted[@]};
do
  if [[ $(awk "BEGIN {print (${realcorr[$i]} >= 0.05)}") == 1 ]];
  then
    exclude="(excluded)"
  else
    fslmaths $cluD/pvalcluster${indexes[$i]} -add $3/correctedClusters $3/correctedClusters
  fi;
  #We read lines 3 and 4 in clusterpat files which correspond to the value of the test and the number of patients
  valTest=`sed -n 4p $tmp/cluster${i}pat.txt`
  numPat=`sed -n 3p $tmp/cluster${i}pat.txt`
  read patients < $tmp/cluster${i}pat.txt;
  read scores < $tmp/cluster${i}sco.txt;
  echo "pvalcluster${indexes[$i]}, ${copysorted[$i]}, ${realcorr[$i]}${exclude}, $valTest, $numPat, $patients" >> $3/clusters.csv;
  echo "pvalcluster${indexes[$i]}, ${copysorted[$i]}, ${realcorr[$i]}${exclude}, $valTest, $numPat, $scores" >> $3/clusters.csv;
done;

declare -a array;
number=0
#We add every clusters without valid pvalues at the end of the first csv file
for ((i=0; i<$numclu; i++));
do
  if [[ ${bonf[$i]} == '' ]];
  then
    array[$number]=$i;
    number=$((number + 1));
  fi;
done;

for i in ${array[@]};
do
  #We read lines 3 and 4 in clusterpat files which correspond to the value of the test and the number of patients
  valTest=`sed -n 4p $tmp/cluster${i}pat.txt`
  numPat=`sed -n 3p $tmp/cluster${i}pat.txt`
  read patients < $tmp/cluster${i}pat.txt;
  read scores < $tmp/cluster${i}sco.txt;
  echo "pvalcluster$i, NaN(-1), NaN, $valTest, $numPat, $patients" >> $3/clusters.csv;
  echo "pvalcluster$i, NaN(-1), NaN, $valTest, $numPat, $scores" >> $3/clusters.csv;
done;

#We create the second csv file if there is warnings
declare -a warn;
bool="false"
for ((i=0; i<$numclu; i++));
do
  warn[$i]=`sed -n '5,$p' $tmp/cluster${i}pat.txt`
  if [[ ${warn[$i]} != '' ]];
  then
    bool="true"
  fi;
done;

if [[ $bool == "true" ]];
then
  echo  "Cluster Name, Warning / Error" > $3/warnings.csv;
  for w in ${!warn[@]};
  do
    if [[ ${warn[$w]} != '' ]];
    then
      echo "pvalcluster$w, ${warn[$w]}" >> $3/warnings.csv;
    fi;
  done;
fi;
#CLEANING

rm -rf $cluD/cluster*
rm -rf $cluD/BHcorrCluster*

if [[ -e $saveTmp ]];
then
  mv $cluD/mergedBHcorrClusters* $3
  mv $cluD $saveTmp;
  #We have to substract subZero to the maskedMeanValMap if we had zeros in scores
  if [[ $8 == "true" ]];
  then
    fslmaths $map -sub $subZero $saveTmp/maskedMeanValMap-$subZero;
  else
    mv $map $saveTmp;
  fi;
  mv $tmp/maskedStd.* $saveTmp;
else
  mv $cluD $tmp/;
fi;
# If you forget to check saveTmp, you can recover tmp files if you don't
# launch anacom2 again

# rm -rf $tmp
