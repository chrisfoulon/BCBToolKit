#! /bin/bash
#Anacom - Serge Kinkingnéhun & Emmanuelle Volle & Michel Thiebaut de Schotten & Chris Foulon 
[ $# -lt 5 ] && { echo "Usage : $0 csvFile LesionFolder ResultFolder threshold controlScores test keepTmp"; exit 1; }

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
#Maybe remove this part for release
if [[ -e $tmp ]];
then
  rm -rf $tmp;
fi;


mkdir -p $tmp

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
# $pat contains patient names (only filenames) and $sco contains scores associated with each patient. 
# ${#path[*]} for number of elements.
echo "${pat[*]}"
echo "TAILLE DE PAT: ${#pat[@]}"
echo "TAILLE DE SCO: ${#sco[@]}"
echo ${sco[*]}
#We have to manage empty lines in the csv file so we unset empty cells
for ((i=0; i < ${#pat[@]};i++)); 
do
  if [[ ${pat[$i]} == "" ]];
  then 
    echo "unset";
    unset pat[$i];
  fi;
  if [[ ${sco[$i]} == "" ]];
  then 
    echo "unset";
    unset sco[$i];
  fi;
done;

for ((i=0; i < ${#pat[@]};i++)); do echo "[${pat[$i]}][${sco[$i]}]"; done; 

#### BINARISATION of ROIs AND ScoredROI creation AND adding binROI in overlapROI and scoROI in overlapScores ####
num=0
oR=$tmp/overlapROI.nii.gz
oS=$tmp/overlapScores.nii.gz
#creating void overlaps one time
fslmaths $2/${pat[0]} -uthr 1 $oR
fslmaths $2/${pat[0]} -uthr 1 $oS
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
echo "MAX : $max";
fslmaths $overMask -thr $max $tmp/layer${nblayer}

fslmaths $overMask -sub $tmp/layer${nblayer} $tmp/eroded

echo "overMask : "`fslstats $overMask -R`
echo "Mean overMask :"`fslstats $overMask -M`
echo "MinMax eroded"`fslstats $tmp/eroded -R`

nblayer=$((nblayer + 1))
while [ `fslstats $tmp/eroded -V | awk '{ print $1 }'` != 0 ];
do
  max=`fslstats $tmp/eroded -R | awk '{print $2}'`;
  echo "MAX : $max";
  fslmaths $tmp/eroded -thr $max $tmp/layer${nblayer}
  
  fslmaths $tmp/eroded -sub $tmp/layer${nblayer} $tmp/eroded
  
  echo "ERODED in loop"`fslstats $tmp/eroded -R`
  nblayer=$((nblayer + 1))
done;
#erorded is now full of 0
rm -rf $tmp/eroded

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
cluD=$3/clusterDir
if [[ -e $cluD ]];
then
  rm -rf $cluD;
fi;


mkdir -p $cluD
numclu=0
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
    echo "MAX : $max";
    fslmaths $tmp/stdlayer -thr $max $cluD/cluster${numclu}
    
    fslmaths $tmp/stdlayer -sub $cluD/cluster${numclu} $tmp/stdlayer
    
    numclu=$((numclu + 1))
    
  done;
done;

#Here we want to find which patients belong to clusters
#For that we try to overlap lesions with clusters
for ((i=0; i<$numclu; i++));
do
  index=0;
  score=0;
  for p in ${pat[*]};
  do
    fslmaths $cluD/cluster$i.nii* -mas $2/$p $tmp/tmpMask${i}_${p};
    #If there is an overlap between cluster and lesion we write the name and 
    #the score else we remove the file
    if [ `fslstats $tmp/tmpMask${i}_${p} -V | awk '{ print $1 }'` == 0 ];
    then 
      rm $tmp/tmpMask${i}_${p}*; 
    else
	  echo -n "$p," >> $tmp/cluster${i}pat.txt
	  echo -n "${sco[$index]}," >> $tmp/cluster${i}sco.txt
    fi;
    index=$((index + 1));
  done;
  ## Note: On OSX, you'd have to use -i '' instead of just -i. ##
  ## Maybe sed does not work on OSX (LO_OL) so ...             ##
  sed -i '$ s/.$//' $tmp/cluster${i}sco.txt
  sed -i '$ s/.$//' $tmp/cluster${i}pat.txt
done;


for f in $tmp/cluster*;
do
  echo $f
  cat $f
  echo " "
  echo "############"
done;

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


#The dirtiness a its pure state
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
if [[ $5 =~ [0-9]*.[0-9]* ]]; 
then
    echo "Only published normative value"
    control="mu=$5"
    echo "$control"
else
    echo "Control scores"
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
	echo "unset";
	unset contr[$i];
      fi;
    done;
    #We create a R vector with control scores
    for ((i=0; i < ${#contr[@]} - 1; i++));
    do
      y=${y}${contr[$i]}","
    done;
    control="c(${y}${contr[-1]})"
    echo "$control"
fi

#We can read clustersco files and apply statistical tests
for ((i=0; i<$numclu; i++));
do
  read text < $tmp/cluster${i}sco.txt
  x="c("$text")"
  compute="myTest($testname($x, $control), \"$tmp/cluster${i}pat.txt\")"
  echo $compute >> $tmp/stats.r
done;

$tmp/stats.r

for ((i=0; i<$numclu; i++));
do
  #We read the second line of every cluster*pat.txt which contain the pvalue
  pval=`sed -n 2p $tmp/cluster${i}pat.txt`
  fslmaths $cluD/cluster${i}.nii* -bin $cluD/cluster${i}pval
  fslmaths $cluD/cluster${i}pval -mul $pval $cluD/cluster${i}pval
  fslmaths $cluD/cluster${i}pval -add $3/mergedPvalClusters $3/mergedPvalClusters
done;

# Creation of a file containing all clusters with pvalues. ($3/mergedPvalClusters)