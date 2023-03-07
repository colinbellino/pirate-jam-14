#!/bin/bash

for i in {1..10}
do
    file="game$i.bin"
    if [ -f "$file" ]; then
        echo "Deleting $file."
        rm $file
    fi
done

echo "Building game0.bin & tactics.bin."
odin build ./src/game -build-mode:dll -out:game0.bin -vet && odin run ./src/tactics -out:tactics.bin -vet
