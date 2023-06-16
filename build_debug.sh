#!/bin/bash

./build_clean_up.sh
./build_copy_libs_to_dist.sh

echo "Building game0.bin in DEBUG mode."
cd dist/
odin build ../src/game -build-mode:dll -out:game0.bin -extra-linker-flags:'-F. -rpath @loader_path' -define=TRACY_ENABLE=true
echo "Building main.bin in DEBUG mode."
odin build ../src/main.odin -file -out:main.bin -extra-linker-flags:'-F. -rpath @loader_path' -define=TRACY_ENABLE=true -debug

