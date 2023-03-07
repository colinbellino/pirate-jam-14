#!/bin/bash


for i in {0..100}
do
    # file="game$i.bin"
    # if [ -f "$file" ]; then
    #     echo "Deleting $file."
    #     rm $file
    # fi
    # file="game$i.exp"
    # if [ -f "$file" ]; then
    #     echo "Deleting $file."
    #     rm $file
    # fi
    # file="game$i.lib"
    # if [ -f "$file" ]; then
    #     echo "Deleting $file."
    #     rm $file
    # fi
    # file="game$i.pdb"
    # if [ -f "$file" ]; then
    #     echo "Deleting $file."
    #     rm $file
    # fi

    file="game$i.bin"
    if ! [[ -f "$file" ]]; then
        echo "Building $file."
        odin build ./src/game -build-mode:dll -out:$file -debug -define:HOT_RELOAD=$i
        exit 0
    fi
done

>&2 echo "ERROR: hot-reload limit reached!"
exit 1
