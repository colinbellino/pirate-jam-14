#!/bin/bash

for i in {0..100}
do
    file="game$i.bin"
    if ! [[ -f "$file" ]]; then
        echo "Building $file."
        odin build ./src/game -build-mode:dll -out:dist/$file -debug -define:HOT_RELOAD=$i
        exit 0
    fi
done

>&2 echo "ERROR: hot-reload limit reached!"
exit 1
