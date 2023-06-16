#!/bin/bash

for i in {0..100}
do
    file="dist/game$i.bin"
    if [ -f "$file" ]; then
        echo "Deleting $file"
        rm $file
    fi
    file="dist/game$i.exp"
    if [ -f "$file" ]; then
        echo "Deleting $file"
        rm $file
    fi
    file="dist/game$i.lib"
    if [ -f "$file" ]; then
        echo "Deleting $file"
        rm $file
    fi
    file="dist/game$i.pdb"
    if [ -f "$file" ]; then
        echo "Deleting $file"
        rm $file
    fi
    file="dist/game$i.o"
    if [ -f "$file" ]; then
        echo "Deleting $file"
        rm $file
    fi
    file="dist/game$i.bin.dSYM"
    if [ -e "$file" ]; then
        echo "Deleting $file"
        rm -rf $file
    fi
done

file="dist/main.bin"
if [ -f "$file" ]; then
    echo "Deleting $file"
    rm $file
fi
file="dist/main.exp"
if [ -f "$file" ]; then
    echo "Deleting $file"
    rm $file
fi
file="dist/main.lib"
if [ -f "$file" ]; then
    echo "Deleting $file"
    rm $file
fi
file="dist/main.pdb"
if [ -f "$file" ]; then
    echo "Deleting $file"
    rm $file
fi
file="dist/main.o"
if [ -f "$file" ]; then
    echo "Deleting $file"
    rm $file
fi
file="dist/main.bin.dSYM"
if [ -e "$file" ]; then
    echo "Deleting $file"
    rm -rf $file
fi
