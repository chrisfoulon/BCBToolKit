#! /bin/bash
[ $# -lt 3 ] && { echo 'Usage :
  $1 = the script to execute
  $2 = the folder of first parameter for $1
  ...'; exit 1; }

# We create the log folder
mkdir -p $5/logs
path=${PWD}/Tools
tmp=$path/tmp/tmp_funcon
if [[ -e $tmp ]];
then
  rm -rf $tmp;
fi;

mkdir $tmp
# We will create a list with the paths of all files inside the $2 folder.
echo -n "" > $tmp/list.txt
for f in $2/*nii*;
do
  echo $f >> $tmp/list.txt
done;

#we will launch N - 1 process where N is the number of processor cores.
ncores=`python -c 'import multiprocessing as mp; print(mp.cpu_count())'`
ncores=$((ncores - 1))
cat $tmp/list.txt | xargs -n 1 -P $ncores -t -I {} \
$1 {} "${@:3}"
