#! /bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cat $DIR/DISCLAIMER.txt
$DIR/jre/bin/java -jar $DIR/sources.jar $DIR
