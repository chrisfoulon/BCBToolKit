#! /bin/bash
#tractotron v1.0 - Michel Thiebaut de Schotten & Chris Foulon

[ $# -lt 3 ] && { echo "Usage : $0 LesionFolder TractsFolder ResultDir"; exit 1; }
#Those lines are the handling of the script's trace and errors
#Traces and errors will be stored in $3/logTractotron.txt
export PS4='+(${LINENO})'
echo -n "" > $3/logTractotron.txt
exec 2>> $3/logTractotron.txt
set -x


path=${PWD}/Tools
lib=$path/libraries/lib
bin=$path/binaries/bin

export LD_LIBRARY_PATH=$lib
export FSLLOCKDIR=""
export FSLMACHINELIST=""
export FSLMULTIFILEQUIT="TRUE"
export FSLOUTPUTTYPE="NIFTI_GZ"
export FSLREMOTECALL=""

mkdir -p $path/tmp/multresh
tmpMult=$path/tmp/multresh

fileName() {
echo -n "$(basename $1 .${1#*.})"
}

proba=$3/probability.xls
prop=$3/proportion.xls
echo -n "" > $prop
echo -n "" > $proba
cd $1
nbPat=0
for d in *.nii*
do
nbPat=$((nbPat + 1))
done
echo "#$nbPat"
cd $2 
printf "\t">>$proba
printf "\t" >> $prop
#We print tract names in xls files and we create tmp Tracts thresholded at 50%
for d in *.nii*
do
printf "%s\t" `fileName $d`>>$proba
printf "%s\t" `fileName $d` >> $prop
$bin/fslmaths $d -thr 0.5 -bin $tmpMult/tmp$d
echo "#"
done
echo "">>$proba
echo "" >> $prop
cd $1
for a in *.nii*
do
  printf  "%s\t" `fileName $a`>>$proba
  printf  "%s\t" `fileName $a` >> $prop
  cd $2
  for b in *.nii*
  do
    $bin/fslmaths $2/$b -mul $1/$a $tmpMult/multresh_$b || (rm -rf $tmpMult; exit 1)
    
    echo "#"
    max=`$bin/fslstats $tmpMult/multresh_$b -R` || (rm -rf $tmpMult; exit 1)
    printf "%s\t" ${max#* }>>$proba
    #Severity calculation
    #First we compute the volume of the tract
    tractVol=`$bin/fslstats $tmpMult/tmp$b -V | awk '{print $1}'`;
    echo "#"
    #Then the volume of the lesion masked with the 50% thresholded tract
    lesTracVol=`$bin/fslstats $1/$a -k $tmpMult/tmp$b -V | awk '{print $1}'`;
    #And we compute the volume ratio between the lesion and the tract
    if [[ $tractVol == "" || $tractVol =~ ^0\.0+$|^0$ ]];
    then 
      printf  "%s\t" "0.000000" >> $prop
    else
      printf  "%s\t" `LC_ALL=en_GB awk "BEGIN {printf \"%.6f\", $lesTracVol / $tractVol}"` >> $prop
    fi;
    echo "#"
  done
  echo "">>$proba
  echo "" >> $prop
done

rm -rf $tmpMult