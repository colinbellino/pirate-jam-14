#!/bin/bash

./build_clean_up.sh

echo "Building game0.bin && tactics.bin."
# ./build_copy_libs_to_dist.sh
odin build ./src/game -build-mode:dll -out:dist/game0.bin && cd dist/ && odin run ../src/tactics.odin -file -out:tactics.bin && cd ..
