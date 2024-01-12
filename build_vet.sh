#!/bin/bash

ctime="./ctime/ctime.exe"
extra=""
mode="-vet"
if [[ "$OSTYPE" == "darwin"* ]]; then
    extra="-extra-linker-flags:-F. -rpath @loader_path"
    ctime="./ctime/ctime"
fi

./build.exe && \

cd dist/ && \
echo "Building game0.dll in RELEASE mode." && \
odin build ../src/game -out:game0.dll -build-mode:dll -define:SOKOL_USE_GL=true -debug "$extra" $mode $1 && \
echo "Building main.exe in RELEASE mode." && \
odin build ../src/main.odin -file -out:main.exe -debug "$extra" $mode $1 && \

cd ../ && \

echo "Done."
