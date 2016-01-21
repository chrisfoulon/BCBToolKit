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


end=`tail -c 1 $1`
if [ "$end" == "" ]; then sed -e :a -e '/^\n*$/ {$d;N;ba' -e '}' "$1"; fi;

sed -e :a -e '/^\n*$/ {$d;N;ba' -e '}' $1 > $tmp/sure.csv
declare -a pat
declare -a sco
while IFS=',' read pat[$i] sco[$i]
do
    i=$((i+1))
done < $tmp/sure.csv
# $pat contains patient names (only filenames) and $sco contains scores associated with each patient. 
# ${#path[*]} for number of elements.
echo "${pat[*]}"
echo "TAILLE DE PAT: ${#pat[@]}"
echo "TAILLE DE SCO: ${#sco[@]}"
echo ${sco[*]}
for ((i=0; i < 5;i++)); do echo "["${pat[$i]}"]"; done;

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
# i is always under ${#pat[*]}(number of patients) because we make an addition of 1 and 
# we make at most ${#pat[*]} additions. 
for ((i=$4; i<${#pat[*]}; i++));
do
  fslmaths $tmp/mask.nii.gz -thr $i -uthr $i $tmp/maskthr_${i}
done;
#Deletes maskthr images which contain only zeros.
for name in $tmp/maskthr_* ; do if [ `fslstats $name -V | awk '{ print $1 }'` = 0 ] ; then echo $name ; rm $name ; fi ; done


i=0
countClu=0
for f in $tmp/maskthr_*;
do
  ##ALGO## Now we make a mask on the OVERMASK with each layer created
  fslmaths $overMask -mas $f $tmp/protoClu_${i};
  
  ##ALGO## We make 26-Neighborhood clusters for every layer(protoClu_...)
  cluster -i $f -t 1 -o ${cluD}/cluster_${i}.nii.gz > $cluD/index_${i}.txt;

  ##ALGO## We create an array (nclu) to store the number of different values in every cluster
  nclu=`fslstats ${cluD}/cluster_${i}.nii.gz -R | awk '{print $2}' | awk -F. '{print $1}'`;

  ##ALGO## We seperate each subClusters (so each different value) in separated files
  for ((n=1;n<=$nclu;n++));
  do
    fslmaths $cluD/cluster_${i} -thr $n -uthr $n $cluD/realClu_${countClu};
    countClu=$((countClu + 1));
  done;
  i=$((i + 1));
done;


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
    fslmaths $cluD/realClu_$i.nii* -mas $2/$p $tmp/tmpMask$p;
    #If there is an overlap between cluster and lesion we write the name and 
    #the score else we remove the file
    if [ `fslstats $tmp/tmpMask$p -V | awk '{ print $1 }'` = 0 ];
    then 
      rm $tmp/tmpMask$p; 
    else
	#Just a if to avoid the last useless comma at the end of the line
	echo $index"INDEX"
	echo $((${#pat[@]}-1))
	echo $((${#pat[@]}))
	if [[ $index -ne $((${#pat[@]}-1)) ]];
	then
	  echo -n "$p," >> $tmp/realClu_${i}pat.txt
	  echo -n "${sco[$index]}," >> $tmp/realClu_${i}sco.txt
	else
	  echo -n "$p" >> $tmp/realClu_${i}pat.txt
	  echo -n "${sco[$index]}" >> $tmp/realClu_${i}sco.txt
	fi;
    fi;
    index=$((index + 1));
  done;
done;


for f in $tmp/realClu_*;
do
  echo $f
  cat $f
  echo "############"
done;