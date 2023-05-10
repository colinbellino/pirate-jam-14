#!/bin/bash

for i in {0..100}
do
    file="dist/game$i.bin"
    if [ -f "$file" ]; then
        echo "Deleting $file."
        rm $file
    fi
    file="dist/game$i.exp"
    if [ -f "$file" ]; then
        echo "Deleting $file."
        rm $file
    fi
    file="dist/game$i.lib"
    if [ -f "$file" ]; then
        echo "Deleting $file."
        rm $file
    fi
    file="dist/game$i.pdb"
    if [ -f "$file" ]; then
        echo "Deleting $file."
        rm $file
    fi
    file="dist/game$i.o"
    if [ -f "$file" ]; then
        echo "Deleting $file."
        rm $file
    fi
    file="dist/game$i.bin.dSYM"
    if [ -f "$file" ]; then
        echo "Deleting $file."
        rm $file
    fi
done

file="dist/tactics.bin"
if [ -f "$file" ]; then
    echo "Deleting $file."
    rm $file
fi
file="dist/tactics.exp"
if [ -f "$file" ]; then
    echo "Deleting $file."
    rm $file
fi
file="dist/tactics.lib"
if [ -f "$file" ]; then
    echo "Deleting $file."
    rm $file
fi
file="dist/tactics.pdb"
if [ -f "$file" ]; then
    echo "Deleting $file."
    rm $file
fi
file="dist/tactics.o"
if [ -f "$file" ]; then
    echo "Deleting $file."
    rm $file
fi
file="dist/tactics.bin.dSYM"
if [ -f "$file" ]; then
    echo "Deleting $file."
    rm $file
fi
