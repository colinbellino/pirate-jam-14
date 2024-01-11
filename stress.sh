#!/bin/bash

./build.exe

extra=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    extra="-extra-linker-flags:-F. -rpath @loader_path"
fi

cd dist/ && \
echo "Building game0.dll." && \
odin build ../src/stress -build-mode:dll -out:game0.dll -debug --max-error-count=1 -define:LOG_ALLOC=false "$extra" ; \
echo "  Done." && \
echo "Running main.exe." && \
odin run ../src/main.odin -file -out:main.exe --max-error-count=1 -debug
