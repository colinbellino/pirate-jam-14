#!/bin/bash

for i in {1..100}
do
    file="game$i.bin"
    if [ -f "$file" ]; then
        echo "Deleting $file."
        rm $file
    fi
    file="game$i.exp"
    if [ -f "$file" ]; then
        echo "Deleting $file."
        rm $file
    fi
    file="game$i.lib"
    if [ -f "$file" ]; then
        echo "Deleting $file."
        rm $file
    fi
    file="game$i.pdb"
    if [ -f "$file" ]; then
        echo "Deleting $file."
        rm $file
    fi
done

file="tactics.bin"
if [ -f "$file" ]; then
    echo "Deleting $file."
    rm $file
fi
file="tactics.exp"
if [ -f "$file" ]; then
    echo "Deleting $file."
    rm $file
fi
file="tactics.lib"
if [ -f "$file" ]; then
    echo "Deleting $file."
    rm $file
fi
file="tactics.pdb"
if [ -f "$file" ]; then
    echo "Deleting $file."
    rm $file
fi
