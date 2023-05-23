#!/bin/bash

./build_clean_up.sh

file="dist/SDL2.dll"
if [ ! -f "$file" ]; then
    ./build_copy_libs_to_dist.sh
fi

echo "Building game0.bin && main.bin."
cd dist/ && \
odin build ../src/game -build-mode:dll -out:game0.bin -define=TRACY_ENABLE=true && \
odin run ../src/main.odin -file -out:main.bin -define=TRACY_ENABLE=true && \
cd ..
