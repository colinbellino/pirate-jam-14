#!/bin/bash

./build_clean_up.sh

echo "Building game0.bin && tactics.bin."
./build_copy_files_to_dist.sh
odin build ./src/game -build-mode:dll -out:dist/game0.bin -define:TRACY_ENABLE=true && cd dist/ && odin run ../src/tactics.odin -file -out:./tactics.bin -define:TRACY_ENABLE=true -define:HOT_RELOAD=true && cd ..
