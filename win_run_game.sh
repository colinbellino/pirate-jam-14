#!/bin/bash

./build_clean_up.sh

file="dist/SDL2.dll"
if [ ! -f "$file" ]; then
    ./build_copy_libs_to_dist.sh
fi

echo "Building game0.bin && tactics.bin."
cd dist/ && odin build ../src/game -build-mode:dll -out:game0.bin -define=TRACY_ENABLE=true && odin run ../src/tactics.odin -file -out:tactics.bin -define=TRACY_ENABLE=true && cd ..
