#!/bin/bash

./build_clean_up.sh
./process_assets.exe

extra=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    extra="-extra-linker-flags:-F. -rpath @loader_path"
fi

cd dist/ && \
echo "Building game0.bin." && \
odin build ../src/stress -build-mode:dll -out:game0.bin "$extra" --max-error-count=1 -debug -define=LOG_ALLOC=false ; \
echo "  Done." && \
echo "Running main.bin." && \
odin run ../src/main.odin -file -out:main.bin --max-error-count=1
