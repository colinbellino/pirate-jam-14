#!/bin/bash

extra=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    extra="-extra-linker-flags:-F. -rpath @loader_path"
fi

./build.exe --CLEAN_UP_CODE && \

cd dist/ && \
echo "Building game0.bin in DEBUG mode." && \
odin build ../src/game -out:game0.bin -build-mode:dll -debug "$extra" $1 && \
echo "Building main.bin in DEBUG mode." && \
odin build ../src/main.odin -file -out:main.bin -debug && \
echo "  Done."
