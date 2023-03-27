#!/bin/bash

./build_clean_up.sh

echo "Building game0.bin in DEBUG mode."
odin build ./src/game -build-mode:dll -out:dist/game0.bin -debug
echo "Building tactics.bin in DEBUG mode."
odin build ./src/tactics.odin -file -out:dist/tactics.bin -debug
