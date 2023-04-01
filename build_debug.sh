#!/bin/bash

./build_clean_up.sh

echo "Building game0.bin in DEBUG mode."
odin build ./src/game -build-mode:dll -out:dist/game0.bin -debug -define=HOT_RELOAD=true
echo "Building tactics.bin in DEBUG mode."
./build_copy_files_to_dist.sh
cd dist/ && odin build ../src/tactics.odin -file -out:./tactics.bin -debug -define=HOT_RELOAD=true && cd ..
