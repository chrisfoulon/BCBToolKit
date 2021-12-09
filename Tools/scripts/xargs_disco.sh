#! /bin/bash
[ $# -lt 3 ] && { echo 'Usage :
  $1 = the script to execute
  $2 = the number of processes to run simultaneously
  $3 = the first parameter for $1
  $4 = the second parameter for $1
  ...'; exit 1; }

# We create the log folder
if [[ -e $4/logs ]];
then
  rm -rf $4/logs;
fi;
mkdir -p $4/logs

# Edits from WD Aug30,2021: commented out two lines below, added 'tmp=$3/tmp_disco'
# path=${PWD}/Tools
# tmp=$path/tmp/tmp_disco
tmp=$4/tmp_disco

if [[ -e $tmp ]];
then
  rm -rf $tmp;
fi;
mkdir -p $tmp

# We will create a list with the paths of all files inside the $2 folder.
echo -n "" > $tmp/list.txt
if [[ `ls -l $3 | wc -l` -lt 2 ]];
then
  echo 'The first input folder is empty ! (╯°□°)╯^┻━┻'
  exit 1;
fi;

if [[ $3 == $4 ]];
then
  echo 'The lesions and results folders are the same ŎםŎ'
  exit 1;
fi;

for f in $3/*nii*;
do
  echo $f >> $tmp/list.txt
done;

#we will launch N - 1 process where N is the number of processor cores.
#ncores=`python -c 'import multiprocessing as mp; print(mp.cpu_count())'`
#ncores=$((ncores - 1))
#cat $tmp/list.txt | xargs -n 1 -P $ncores -t -I {} $1 {} "${@:3}"

# Temporary fix, it's slowing down the process but it works.
cat $tmp/list.txt | xargs -n 1 -P $2 -t -I {} $1 {} "${@:3}"
