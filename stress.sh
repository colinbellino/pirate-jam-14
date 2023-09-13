#!/bin/bash

./build.exe --CLEAN_UP_CODE

extra=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    extra="-extra-linker-flags:-F. -rpath @loader_path"
fi

cd dist/ && \
echo "Building game0.bin." && \
odin build ../src/stress -build-mode:dll -out:game0.bin -debug --max-error-count=1 -define:LOG_ALLOC=false "$extra" ; \
echo "  Done." && \
echo "Running main.bin." && \
odin run ../src/main.odin -file -out:main.bin --max-error-count=1 -debug
