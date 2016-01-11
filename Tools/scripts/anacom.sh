#! /bin/bash
#Anacom - Serge Kinkingnéhun & Michel Thiebaut de Schotten & Chris Foulon 

set -x

#We can juste have patient files and one mean value as parameter


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