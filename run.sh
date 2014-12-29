#!/bin/bash

for FILE in `find . -name "*.js" -type f -o -path './node_modules' -prune -o -path './components' -prune`
do
    if [ -e $FILE ] ; then
        COFFEE=${FILE//.js/.coffee}

        echo "converting ${FILE} to ${COFFEE}"
        js2coffee "$FILE" > "$COFFEE"
    else
        echo "File: {$1} does not exist!"
    fi
done
