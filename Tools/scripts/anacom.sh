#! /bin/bash
#Anacom - Serge Kinkingnéhun & Michel Thiebaut de Schotten & Chris Foulon 
[ $# -lt 5 ] && { echo "Usage : $0 csvFile LesionFolder ResultFolder threshold keepTmp"; exit 1; }

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
echo ${pat[*]}
echo ${sco[*]}

#### BINARISATION of ROIs AND ScoredROI creation AND adding binROI in overlapROI and scoROI in overlapScores ####
num=0
oR=$tmp/overlapROI.nii.gz
oS=$tmp/overlapScores.nii.gz
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

#### Mean Values Map ####
#We just devide overlapScores by overlapROI in meanValMap.nii.gz
fslmaths $oS -div $oR $tmp/meanValMap.nii.gz

#### Thresholding the overlapROI in mask.nii.gz ####
fslmaths $oR -thr $4 $tmp/mask.nii.gz

#### Applying the mask to meanValMap.nii.gz ####
map=$tmp/$maskedMeanValMap.nii.gz
fslmaths $tmp/$meanValMap.nii.gz -mas $tmp/mask.nii.gz $map

#### Clustering and Labelisation ####
#We keep cluster's results in the result directory
cluD=$3/clusterDir
mkdir $cluD
cluster -i $map -t $4 -o $cluD/cluster.nii.gz > $cluD/index.txt

nclu=`fslstats $cluD/cluster.nii.gz -R | awk '{print $2}' | awk -F. '{print $1}'`

for ((i=1;i<=nclu;i++)); 
do

    fslmaths $cluD/cluster.nii.gz -thr ${i} -uthr $cluD/${i} $clu_${i}

done
#./Tools/scripts/anacom.sh /home/tolhs/MesDocuments/ANACOM/anacom-ev/testAnacom/testAnacom.csv /home/tolhs/MesDocuments/ANACOM/anacom-ev/testAnacom /home/tolhs/MesDocuments/ANACOM/anacom-ev/testAnacom 3 true
