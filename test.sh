#!/bin/bash

extra=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    extra="-extra-linker-flags:-F. -rpath @loader_path"
fi

cd dist/ && \
odin test ../src/game -define:SOKOL_USE_GL=true "$extra" && \
cd ../
