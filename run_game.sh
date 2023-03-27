#!/bin/bash

./build_clean_up.sh

echo "Building game0.bin && tactics.bin."
odin build ./src/game -build-mode:dll -out:dist/game0.bin -define:TRACY_ENABLE=true && odin run ./src/tactics.odin -file -out:dist/tactics.bin -define:TRACY_ENABLE=true -define:HOT_RELOAD=true
