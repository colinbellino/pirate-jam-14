#!/bin/bash

extra=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    extra="-extra-linker-flags:-F. -rpath @loader_path"
fi

odin build ./src/build.odin -file -out:build.exe -o=speed "$extra" -define:PROFILER=true
