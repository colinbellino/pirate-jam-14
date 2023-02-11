#!/bin/bash

if [[ $1 == "Windows" ]]; then
    platform="Windows"
    output="tactics.exe"
elif [[ $1 == "Mac" ]]; then
    platform="Mac"
    output="tactics.bin"
elif [[ $1 == "Linux" ]]; then
    platform="Linux"
    output="tactics.bin"
else
    echo "Invalid platform: $1"
    exit 0
fi

date_time=$(date +%Y-%m-%d_%H-%M)
echo "---------------------------------------------"
echo "Building for $platform: $date_time           "
echo "---------------------------------------------"

./build_version.sh

mkdir -p ./builds/$platform/$date_time
odin build ./src/tactics.odin -file -out:./builds/$platform/$date_time/$output -o:speed $3

if [[ $2 == "--run" ]]; then
    ./builds/$platform/$date_time/$output
fi
