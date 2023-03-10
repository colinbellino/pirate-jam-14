#!/bin/bash

./build_clean_up.sh

echo "Building game0.bin && tactics.bin."
odin build ./src/game -build-mode:dll -out:game0.bin -define:HOT_RELOAD=0 && odin run ./src/tactics -out:tactics.bin
