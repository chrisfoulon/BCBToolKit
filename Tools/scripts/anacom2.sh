#! /bin/bash
#Anacom - Serge Kinkingnéhun & Michel Thiebaut de Schotten & Chris Foulon 
[ $# -lt 5 ] && { echo "Usage : $0 csvFile LesionFolder ResultFolder threshold keepTmp"; exit 1; }
###############################################################################
## WARNING : The csv file MUST not have empty lines, this is manage          ##
## in the java interface.                                                    ##
###############################################################################
# set -x

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

#### Clustering and Labelisation ####
#We keep cluster's results in the result directory
cluD=$3/clusterDir

#Remove this part too
if [[ -e $cluD ]];
then
  rm -rf $cluD;
fi;


mkdir -p $cluD
# Here we extract each layer of the thresholded masked map, that's why we start at $4
# i is less or equals ${#pat[*]}(number of patients) because we make an addition of 1 and 
# we make at most ${#pat[*]} additions. 
for ((i=$4; i<=${#pat[*]}; i++));
do
  fslmaths $tmp/mask.nii.gz -thr $i -uthr $i $tmp/maskthr_${i}
done;
#Delete maskthr images which contain only zeros.
for name in $tmp/maskthr_* ; do if [ `fslstats $name -V | awk '{ print $1 }'` = 0 ] ; then echo $name ; rm $name ; fi ; done


# For each layer extracted before, we make other layers for each value found
nblayer=0
for f in $tmp/maskthr_*;
do
  name=$(basename "$f")
  scored=$tmp/scored$name
  fslmaths $overMask -mas $f $scored
  max=`fslstats $scored -R | awk '{print $2}'`;
  echo "MAX : $max";
  fslmaths $scored -thr $max $tmp/layer${nblayer}
  
  fslmaths $scored -sub $tmp/layer${nblayer} $tmp/eroded${name}
  
  echo "maskthr : "`fslstats $scored -R`
  echo "MinMax eroded"`fslstats $tmp/eroded${name} -R`
  echo "Mean maskthr :"`fslstats $scored -M`
  nblayer=$((nblayer + 1))
  while [ `fslstats $tmp/eroded${name} -V | awk '{ print $1 }'` != 0 ];
  do
    max=`fslstats $tmp/eroded${name} -R | awk '{print $2}'`;
    echo "MAX : $max";
    fslmaths $tmp/eroded${name} -thr $max $tmp/layer${nblayer}
    
    fslmaths $tmp/eroded${name} -sub $tmp/layer${nblayer} $tmp/eroded${name}
    
    echo "ERODED in loop"`fslstats $tmp/eroded${name} -R`
    nblayer=$((nblayer + 1))
  done;
done;

  rm -rf $tmp/eroded*

i=0
countClu=0
for f in $tmp/layer*;
do
  ##ALGO## Now we make a mask on the OVERMASK with each layer created
  fslmaths $overMask -mas $f $tmp/protoClu_${i};
  
  ##ALGO## We make 26-Neighborhood clusters for every layer(protoClu_...)
  cluster -i $tmp/protoClu_${i} -t 1 -o ${cluD}/cluster_${i}.nii.gz > $cluD/index_${i}.txt;

  ##ALGO## nclu store the number of different values in every cluster
  nclu=`fslstats ${cluD}/cluster_${i}.nii.gz -R | awk '{print $2}' | awk -F. '{print $1}'`;

  ##ALGO## We seperate each subClusters (so each different value) in separated files
  for ((n=1;n<=$nclu;n++));
  do
    fslmaths $cluD/cluster_${i} -thr $n -uthr $n $cluD/realClu_${countClu};
    countClu=$((countClu + 1));
  done;
  i=$((i + 1));
done;

#Here we have all clusters, now we have to retrieve patients and scores
#contained in each cluster.


# Creation of a file containing all clusters, I don't know if it's useful. 
find_the_biggest $cluD/realClu_* $3/addedClusters

##ALGO## Now we will retrieve data about content of clusters (patients and scores)
## On pourrait commencer à construire le script R dans ces boucles !
rm -rf $tmp/realClu_*
for ((i=0; i<$countClu; i++));
do
  index=0;
  for p in ${pat[*]};
  do
    fslmaths $cluD/realClu_$i.nii* -mas $2/$p $tmp/tmpMask${i}_${p};
    #If there is an overlap between cluster and lesion we write the name and 
    #the score else we remove the file
    if [ `fslstats $tmp/tmpMask${i}_${p} -V | awk '{ print $1 }'` == 0 ];
    then 
      echo  "RM"
      rm $tmp/tmpMask${i}_${p}*; 
    else
	  echo -n "$p," >> $tmp/realClu_${i}pat.txt
	  echo -n "${sco[$index]}," >> $tmp/realClu_${i}sco.txt
    fi;
    index=$((index + 1));
  done;
  ## Note: On OSX, you'd have to use -i '' instead of just -i. ##
  ## Maybe sed does not work on OSX (LO_OL) so ...             ##
  sed -i '$ s/.$//' $tmp/realClu_${i}sco.txt
  sed -i '$ s/.$//' $tmp/realClu_${i}pat.txt
done;


for f in $tmp/realClu_*;
do
  echo $f
  cat $f
  echo " "
  echo "############"
done;

######################## Linear Regression (USELESS ?) ##########################
vec="${sco[0]}"
for ((i=1; i < ${#sco[@]};i++));
do
  vec="${vec},${sco[$i]}"
done;

for ((i=0; i < ${#pat[@]};i++));
do
  vox[$i]=`fslstats $2/${pat[$i]} -V | awk '{ print $1 }'`
done;

voxvec="${vox[0]}"
for ((i=1; i < ${#vox[@]};i++));
do
  voxvec="${voxvec},${vox[$i]}"
done;

echo '#!/usr/bin/env Rscript' > $tmp/linReg.r
chmod +x $tmp/linReg.r

echo "linM <- lm(c($vec) ~ c($voxvec))" >> $tmp/linReg.r
echo "resid(linM)" >> $tmp/linReg.r
echo "cat(linM\$residuals, \"\n\", file=\"$tmp/resid.txt\")" >> $tmp/linReg.r

$tmp/linReg.r

######################## Linear Regression (END) ##########################