#! /bin/bash
#AnaCOM2 - Serge Kinkingnéhun & Emmanuelle Volle & Michel Thiebaut de Schotten & Chris Foulon 
[ $# -lt 5 ] && { echo "Usage : $0 csvFile LesionFolder ResultFolder threshold controlScores test keepTmp"; exit 1; }
#This command crash the software but for now I don't know why
#set -x
#set -e

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
#Maybe remove this part for release
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
while IFS=',' read pat[$i] sco[$i]
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

nblayer=$((nblayer + 1))
while [ `fslstats $tmp/eroded -V | awk '{ print $1 }'` != 0 ];
do
  max=`fslstats $tmp/eroded -R | awk '{print $2}'`;
  fslmaths $tmp/eroded -thr $max $tmp/layer${nblayer}
  
  fslmaths $tmp/eroded -sub $tmp/layer${nblayer} $tmp/eroded
  
  nblayer=$((nblayer + 1))
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
  # In first we mask std with the layer
  fslmaths $tmp/maskedStd -mas $la $tmp/tmpStdMask
  # We add std to the layer
  fslmaths $la -add $tmp/tmpStdMask $tmp/stdlayer
  # And now we make other layers, with each different values, which will be 
  # our clusters
  while [ `fslstats $tmp/stdlayer -V | awk '{ print $1 }'` != 0 ];
  do 
    max=`fslstats $tmp/stdlayer -R | awk '{print $2}'`;
    fslmaths $tmp/stdlayer -thr $max $cluD/cluster${numclu};
    fslmaths $tmp/stdlayer -sub $cluD/cluster${numclu} $tmp/stdlayer;
    #Be careful, here, in clusters, we have the added scores of patients 
    #ADDED to the standard deviation. For now we don't use this value but it could
    #make errors if we use it. (Solution is to substract each cluster by maskedStd
    numclu=$((numclu + 1));
  done;
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
      rm $tmp/tmpMask${i}_${p}*; 
    else
      patient="$patient$p,"
      score="$score${sco[$index]},"
    fi;
    index=$((index + 1));
  done;
  #We remove the last comma of strings and we store values in files
  echo -n "${patient:0:${#patient}-1}" >> $tmp/cluster${i}pat.txt
  echo -n "${score:0:${#score}-1}" >> $tmp/cluster${i}sco.txt
done;
echo "#"

# A loop to test if there is no overlap between clusters
# for ((i=0; i < $numclu; i++));
# do
#   for ((j=$i + 1; j < $numclu; j++));
#   do 
#     fslmaths $cluD/cluster${i}.nii* -mas $cluD/cluster${j}.nii* $tmp/clustOverlap
#     if [ `fslstats $tmp/clustOverlap -V | awk '{ print $1 }'` == 0 ];
#     then 
#       echo "Ok c'est tout bon"
#     else
#       echo "La c'est la galère"
#     fi;
#   done;
# done;

#We have our clusters, now let's make stats ! \o/


#Just define the test we will compute
if [[ $6 == "Wilcoxon" ]];
then 
  testname="wilcox.test";
elif [[ $6 == "t-test" ]];
then
  testname="t.test";
elif [[ $6 == "Kolmogorov-Smirnov" ]];
then
  testname="ks.test"
else
  echo "This test is unknown"
fi;

echo '#!/usr/bin/env Rscript' > $tmp/stats.r
chmod +x $tmp/stats.r

echo 'options(warn=-1)' >> $tmp/stats.r

#The dirtiness at its pure state
echo 'myTest <- function(fun = stat(x, y), patfile) {' >> $tmp/stats.r
echo '  res <- try(fun);' >> $tmp/stats.r
echo '  w <- NULL;'  >> $tmp/stats.r
echo '  if (class(res) == "try-error") {'  >> $tmp/stats.r
echo '    res$p.value <- NaN;' >> $tmp/stats.r
echo '  } else if (exists("last.warning") && !is.null(last.warning)) {'  >> $tmp/stats.r
echo '    w <- paste("Warning", names(last.warning), sep=" : ");' >> $tmp/stats.r
echo '    assign("last.warning", NULL, envir = baseenv());'  >> $tmp/stats.r
echo '  } ' >> $tmp/stats.r
echo '  write(paste("\n", res$p.value, sep=""), patfile, append=TRUE, sep="\n");'  >> $tmp/stats.r
echo '  if (!is.null(w)) {'  >> $tmp/stats.r
echo '    write(paste("\n", w, sep=""), patfile, append=TRUE, sep="\n");' >> $tmp/stats.r
echo '  }'  >> $tmp/stats.r
echo '}' >> $tmp/stats.r
#We need control scores, we can have a mean if we have wilcoxon or ttest
#Or a vector of scores which will be a column in a csv file
if [[ $5 =~ [0-9]+\.[0-9]+|[0-9]+ ]]; 
then
    control="mu=$5"
else
    i=0
    declare -a contr
    while read contr[$i]
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
    #We create a R vector with control scores
    cc=0
    declare -a full
    for ct in ${contr[*]};
    do
      full[$cc]=$ct
      cc=$((cc + 1))
    done;
    for ((i=0; i < ${#full[@]} - 1; i++));
    do
      y="${y}${full[$i]},"
    done;
    control="c(${y}${full[${#full[@]} - 1]})"
fi

#We can read clustersco files and apply statistical tests
for ((i=0; i<$numclu; i++));
do
  read text < $tmp/cluster${i}sco.txt
  x="c("$text")"
  compute="myTest($testname($x, $control), \"$tmp/cluster${i}pat.txt\")"
  echo $compute >> $tmp/stats.r
done;

#We launch the R script to compute pvalues
$tmp/stats.r

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
    bonf[$i]=$pval;
  else
    pval=-1
  fi;
  # if pval != 0 
  if [ `awk "BEGIN { print ($pval == 0)}"` == 0 ];
  then
    # We round $pval
    pval=$(awk "BEGIN {printf \"%.6f\", $pval}")
    # If $pval is round to 0.000000 we set pval to 0.000001 because it means that
    # the real pval is less than 0.000001
    pval=$(awk "BEGIN { if ($pval == 0) print \"0.000001\"; else print $pval }")
  fi;
  
  fslmaths $cluD/cluster${i} -bin $cluD/pvalcluster${i}
  
  fslmaths $cluD/pvalcluster${i} -mul $pval $cluD/pvalcluster${i}
  # Creation of a file containing all clusters with pvalues. ($3/mergedPvalClusters)
  fslmaths $cluD/pvalcluster${i} -add $3/mergedPvalClusters $3/mergedPvalClusters
done;
#Here we have all pvalues (without NaN) stored in bonf indexed by cluster number
#To correct pvalues with Bonferroni-Holm method we have to sort them in ascending order
declare -a sorted;
declare -a indexes;
# Sort with -g (for floats) and -s for stable sort (to preserve order in case of equality)
var=`for i in "${bonf[@]}"; do echo "$i"; done | sort -g -s`
# Sort give a string so we convert it as an array in $sorted
IFS=' ' read -r -a sorted <<< $var
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
done;

# We make Bonferroni-Holm corrections
numb=${#sorted[@]}
for ((i=0;i<${#sorted[@]};i++));
do
  sorted[$i]=$(awk "BEGIN {printf \"%.6f\", ${sorted[$i]}*$((numb - $i))}");

  # If sorted[$i] is round to 0.000000 we set sorted[$i] to 0.000001 because it means that
  # the real sorted[$i] is less than 0.000001
  sorted[$i]=$(awk "BEGIN { if (${sorted[$i]} == 0) print \"0.000001\"; else print ${sorted[$i]} }")
done;
# We re-create bonf with corrected pvalues
for ((i=0;i<${#sorted[@]};i++));
do
  bonf[${indexes[$i]}]=${sorted[$i]};
done;
# We create new maps with corrected pvalues
fslmaths $overMask -mul 0 $3/mergedBHcorrClusters
for index in ${!bonf[@]};
do
  fslmaths $cluD/pvalcluster${index} -bin $cluD/BHcorrCluster${index}
  fslmaths $cluD/BHcorrCluster${index} -mul ${bonf[$index]} $cluD/BHcorrCluster${index}
  # We fill the map with all corrected pvalues
  fslmaths $cluD/BHcorrCluster${index} -add $3/mergedBHcorrClusters $3/mergedBHcorrClusters
done;


# Bonferroni correction
fslmaths $3/mergedPvalClusters -mul $numclu $tmp/tmpbonf

fslmaths $tmp/tmpbonf -uthr 1 -bin $tmp/ubonfmask

fslmaths $tmp/tmpbonf -thr 1 -bin $tmp/bonfmask

fslmaths $tmp/tmpbonf -mas $tmp/ubonfmask -add $tmp/bonfmask $3/bonferroniClusters
echo "#"

rm -rf $cluD/cluster*

if [[ -e $saveTmp ]];
then
  mv $map $saveTmp;
  mv $tmp/maskedStd.* $saveTmp;
else
  rm -rf $cluD
fi;

rm -rf $tmp

#I realised that all issues with arrays when I unset values could be resolve
#by using ${!array[@]} which give indexes of array even if there are not 
#contiguous.