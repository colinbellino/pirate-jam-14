#!/bin/bash

./build.exe

extra=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    extra="-extra-linker-flags:-F. -rpath @loader_path"
fi

cd dist/ && \
echo "Building game0.dll." && \
odin build ../src/stress -build-mode:dll -out:game0.dll "$extra" --max-error-count=1 -disable-assert -no-bounds-check -o:speed -define:TRACY_ENABLE=true -define:PROFILER=true -define:GPU_PROFILER=false -define:LOG_ALLOC=false -define:IMGUI_ENABLE=true ; \
echo "  Done." && \
echo "Running main.exe." && \
odin run ../src/main.odin -file -out:main.exe --max-error-count=1
