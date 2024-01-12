#!/bin/bash

ctime="./ctime/ctime.exe"
extra=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    extra="-extra-linker-flags:-F. -rpath @loader_path"
    ctime="./ctime/ctime"
fi

"$ctime" -begin jam_debug.ctm

./build.exe && \

cd dist/ && \
echo "Building game0.dll in DEBUG mode." && \
odin build ../src/game -out:game0.dll -build-mode:dll -debug -define:SOKOL_USE_GL=true "$extra" $1 && \
echo "Building main.exe in DEBUG mode." && \
odin build ../src/main.odin -file -out:main.exe -debug && \

cd ../ && \
"$ctime" -end jam_debug.ctm %LastError% && \

if [[ "$OSTYPE" == "msys" && $2 == "debug" ]]; then
    echo "Starting RemedyBG..." && \
    remedybg start-debugging
else
    echo "No debugger to start." && \
    cd dist/ && \
    ./main.exe
fi
