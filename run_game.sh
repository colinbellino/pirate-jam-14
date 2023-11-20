#!/bin/bash

extra=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    extra="-extra-linker-flags:-F. -rpath @loader_path"
fi

./build.exe --CLEAN_UP_CODE && \

cd dist/ && \
echo "Building game0.bin." && \
odin build ../src/game -build-mode:dll -out:game0.bin --max-error-count=2 -debug "$extra" $1 && \
echo "  Done." && \
echo "Running main.bin." && \
odin run ../src/main.odin -file -out:main.bin --max-error-count=2 -debug
