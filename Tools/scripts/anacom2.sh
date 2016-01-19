#! /bin/bash
#Anacom - Serge Kinkingnéhun & Michel Thiebaut de Schotten & Chris Foulon 
[ $# -lt 5 ] && { echo "Usage : $0 csvFile LesionFolder ResultFolder threshold keepTmp"; exit 1; }

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
#(juste in ttest case). 

#### READING the csv file containing patient name and their score ####
#Counter for adding value in cells 
i=0
#Here we fill arrays with the two columns of the csv file, IFS define separators 
while IFS=, read pat[$i] sco[$i]
do
    i=$((i+1))
done < $1
# $pat contains patient names (only filenames) and $sco contains scores associated with each patient. ${pat[i]} to acces
# ${#path[*]} for number of elements.
echo ${pat[*]}
echo ${sco[*]}

#### BINARISATION of ROIs AND ScoredROI creation AND adding binROI in overlapROI and scoROI in overlapScores ####
num=0
oR=$tmp/overlapROI.nii.gz
oS=$tmp/overlapScores.nii.gz
#creating void overlaps one time
fslmaths $2/${pat[1]} -uthr 1 $oR
fslmaths $2/${pat[1]} -uthr 1 $oS
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
for f in $tmp/maskthr_*;
do
  ##ALGO## Now we make a mask on the OVERMASK with each layer created
  fslmaths $overMask -mas $f $tmp/protoClu_${i};
  
  ##ALGO## We make 26-Neighborhood clusters for every layer(protoClu_...)
  cluster -i $f -t 1 -o ${cluD}/cluster_${i}.nii.gz > $cluD/index_${i}.txt;
  echo "Je passe par là"
  ##ALGO## We create an array (nclu) to store the number of different values in every cluster
  nclu=`fslstats ${cluD}/cluster_${i}.nii.gz -R | awk '{print $2}' | awk -F. '{print $1}'`;
  echo "nclu : $nclu"
  ##ALGO## We seperate each subClusters (so each different value) in separated files
  for ((n=1;n<=$nclu;n++));
  do echo $n
    fslmaths $cluD/cluster_${i} -thr $n -uthr $n $cluD/realClu_${i}_${n};
  done;
  i=$((i + 1));
done;


# find_the_biggest reecrit une serie d'image en une seule image ou chaque image a un numero qui correspond à cette image de façon sequentielle. Si deux images se superposent sur certains voxels (ce qui n'est pas le cas ici) l'image avec la valeur la plus forte dans ce voxel gagne.
find_the_biggest $cluD/realClu_* $3/ClusterCool