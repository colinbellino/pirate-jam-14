#!/bin/bash

for i in {1..10}
do
    file="game-hot$i.bin"
    if [ -f "$file" ]; then
        echo "Deleting $file."
        rm $file
    fi
done

echo "Building game"
odin build ./src/game -build-mode:dll -out:game.bin && odin run ./src/tactics.odin -file -out:tactics.bin
