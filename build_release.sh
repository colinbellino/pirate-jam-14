#!/bin/bash

extra=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    extra="-extra-linker-flags:-F. -rpath @loader_path"
fi

./build_clean_up.sh && \
./build_copy_libs_to_dist.sh && \
./build_copy_media_to_dist.sh && \

cd dist/ && \

echo "Building game0.bin in RELEASE mode." && \
odin build ../src/game -build-mode:dll -out:game0.bin "$extra" --max-error-count=1 -define=LOG_ALLOC=false -define=HOT_RELOAD_CODE=false -define=HOT_RELOAD_ASSETS=false -define:ASSETS_PATH="./" && \
echo "  Done."

echo "Building main.bin in RELEASE mode." && \
odin build ../src/main.odin -file -out:main.bin && \
echo "  Done."
