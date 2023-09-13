#!/bin/bash

extra=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    extra="-extra-linker-flags:-F. -rpath @loader_path"
fi

./build.exe --CLEAN_UP_CODE && \

cd dist/ && \

echo "Building game0.bin in RELEASE mode." && \
odin build ../src/game -build-mode:dll -out:game0.bin "$extra" --max-error-count=1 -disable-assert -no-bounds-check -o=speed -define:TRACY_ENABLE=false -define:PROFILER=false -define:LOG_ALLOC=false -define:HOT_RELOAD_CODE=false -define:HOT_RELOAD_ASSETS=false -define:RENDERER=1 && \
echo "  Done."

echo "Building main.bin in RELEASE mode." && \
odin build ../src/main.odin -file -out:main.bin -disable-assert -no-bounds-check -o=speed -define:TRACY_ENABLE=false -define:PROFILER=false -define:LOG_ALLOC=false && \
echo "  Done."
