DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cat $DIR/DISCLAIMER.txt
JAVA_BIN="$DIR/jre/bin/java"
if [ ! -f "$JAVA_BIN" ]; then
    JAVA_BIN="$(which java)"
fi
"$JAVA_BIN" -jar "$DIR/sources.jar" "$DIR"

