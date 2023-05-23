#!/bin/bash

./build_clean_up.sh

echo "Building game0.bin & main.bin in VET mode."
odin build ./src/game -build-mode:dll -out:dist/game0.bin -vet -extra-linker-flags:'-F. -rpath @loader_path' && odin build ./src/main.odin -file -out:dist/main.bin -vet -extra-linker-flags:'-F. -rpath @loader_path'
