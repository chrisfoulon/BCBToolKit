#! /bin/bash
#tractotron v1.0 - Michel Thiebaut de Schotten & Chris Foulon

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
cd $1
nbPat=0
for d in *.nii*
do
nbPat=$((nbPat + 1))
done
echo "#$nbPat"
cd $2
#L'option -e permet d'interpréter des \ ainsi on peut ajouter les tabulations séparant les cellules. 
printf "\t">>$3
for d in *.nii*
do
printf "%s\t" $d>>$3
done
echo "">>$3
cd $1
for a in *.nii*
do
  printf  "%s\t" $a>>$3
  cd $2
  for b in *.nii*
  do
    $bin/fslmaths $2/$b -mul $1/$a $tmpMult/multresh_$b || (rm -r $tmpMult; exit 1)
    max=`$bin/fslstats $tmpMult/multresh_$b -R` || (rm -r $tmpMult; exit 1)
    printf "%s\t" ${max#* }>>$3
    #Attention changement ici (normalement il est sur la ligne du dessous.
    echo "#"
  done
  echo "">>$3
done
rm -r $tmpMult
perl -pi -w -e 's/.nii.gz//g;' $3 || (rm -r $tmpMult; exit 1)
perl -pi -w -e 's/.nii//g;' $3 || (rm -r $tmpMult; exit 1)
perl -pi -w -e 's/\t\n/\n/g;' $3 || (rm -r $tmpMult; exit 1)