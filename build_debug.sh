#!/bin/bash

./build_clean_up.sh

echo "Building game0.bin & tactics.bin in DEBUG mode."
odin build ./src/game -build-mode:dll -out:game0.bin -debug && odin build ./src/tactics -out:tactics.bin -debug
