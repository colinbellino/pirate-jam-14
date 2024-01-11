#!/bin/bash

# ./build.exe

extra=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    extra="-extra-linker-flags:-F. -rpath @loader_path"
fi

./build.exe && \

cd dist/ && \
echo "Building game0.dll." && \
odin build ../src/sandbox -build-mode:dll -out:game0.dll -debug -define:IMGUI_ENABLE=true -define:SOKOL_USE_GL=true "$extra" && \
echo "  Done." && \
echo "Running main.exe." && \
odin run ../src/main.odin -file -out:main.exe --max-error-count=1 -debug
