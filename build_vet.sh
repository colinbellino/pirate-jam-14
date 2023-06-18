#!/bin/bash

extra=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    extra="-extra-linker-flags:-F. -rpath @loader_path"
fi

./build_clean_up.sh
./build_copy_libs_to_dist.sh

cd dist/
echo "Building game0.bin in VET mode."
odin build ../src/game -out:game0.bin -build-mode:dll "$extra" -vet
echo "  Done."
echo "Building main.bin in VET mode."
odin build ../src/main.odin -file -out:main.bin -vet
echo "  Done."
