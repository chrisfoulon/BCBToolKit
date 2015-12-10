#! /bin/bash

if [ `uname` == "Linux" ]
then
path=${PWD}
elif [`uname` == "Darwin"]
then
path=$(dirname $0)
else
echo "Your OS is not recognized by this application, please report this error and the following line : "
echo $uname
fi
cat $path/DISCLAIMER

$path/jre/bin/java -jar $path/sources.jar $path
 
 
