#!/bin/bash

extra=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    extra="-extra-linker-flags:-F. -rpath @loader_path"
fi

cd dist/ && \
odin test ../src/engine "$extra" $1 ; \
odin test ../src/game "$extra" $1 && \
cd ..
