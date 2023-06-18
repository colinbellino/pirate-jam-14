#!/bin/bash

./build_clean_up.sh
./build_copy_libs_to_dist.sh

extra=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    extra="-extra-linker-flags:'-F. -rpath @loader_path'"
fi

cd dist/
echo "Building game0.bin in DEBUG mode."
odin build ../src/game -out:game0.bin -build-mode:dll $extra -define=TRACY_ENABLE=true -debug
echo "Building main.bin in DEBUG mode."
odin build ../src/main.odin -file -out:main.bin -define=TRACY_ENABLE=true -debug
