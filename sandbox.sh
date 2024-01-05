#!/bin/bash

# ./build.exe --CLEAN_UP_CODE

extra=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    extra="-extra-linker-flags:-F. -rpath @loader_path"
fi

./build.exe --CLEAN_UP_CODE && \

cd dist/ && \
echo "Building game0.bin." && \
odin build ../src/sandbox -build-mode:dll -out:game0.bin -debug -define:IMGUI_ENABLE=true -define:SOKOL_USE_GL=true "$extra" && \
echo "  Done." && \
echo "Running main.bin." && \
odin run ../src/main.odin -file -out:main.bin --max-error-count=1 -debug
