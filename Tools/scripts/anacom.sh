#! /bin/bash
#Anacom - Serge Kinkingnéhun & Michel Thiebaut de Schotten & Chris Foulon 

#Counter for adding value in cases 
i=0
#Here we fill arrays with the two columns of the csv file 
while IFS=, read pat[$i] sco[$i]
do
    i=$((i+1))
done < $1
# $pat contains patient names (only filenames) and $sco contains scores associated with each patient. ${pat[i]} to acces
echo ${pat[*]}
echo ${sco[*]}