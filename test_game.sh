#!/bin/bash

echo "Testing src/game"
cd dist/ && \
odin test ../src/game -extra-linker-flags:'-F. -rpath @loader_path' -define=TRACY_ENABLE=true && \
cd ..
