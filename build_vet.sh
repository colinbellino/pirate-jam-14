#!/bin/bash

./build_clean_up.sh

echo "Building game0.bin & tactics.bin in VET mode."
odin build ./src/game -build-mode:dll -out:game0.bin -vet && odin build ./src/tactics.odin -file -out:tactics.bin -vet
