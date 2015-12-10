#! /bin/bash

path=${PWD}/Tools

if ! [[ -e $path/installR/oro.nifti ]]
then
    
    R CMD INSTALL $path/extraFiles/RLibsArchives/oro.nifti_0.5.2.tar.gz -l $path/installR
fi

if ! [[ -e $path/installR/plyr ]]
then
    
    R CMD INSTALL $path/extraFiles/RLibsArchives/plyr_1.8.3.tar.gz -l $path/installR
fi
    
if ! [[ -e $path/installR/psych ]]
then
    R CMD INSTALL $path/extraFiles/RLibsArchives/psych_1.5.8.tar.gz -l $path/installR
fi

if ! [[ -e $path/installR/GPArotation ]]
then
    R CMD INSTALL $path/extraFiles/RLibsArchives/GPArotation_2014.11-1.tar.gz -l $path/installR
fi