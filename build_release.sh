#!/bin/bash

ctime="./ctime/ctime.exe"
extra=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    extra="-extra-linker-flags:-F. -rpath @loader_path"
    ctime="./ctime/ctime"
fi

"$ctime" -begin snowball2_release.ctm

./build.exe && \

cd dist/ && \
echo "Building game0.bin in RELEASE mode." && \
odin build ../src/game -out:game0.bin -build-mode:dll -disable-assert -no-bounds-check -o:aggressive -define:SOKOL_USE_GL=true "$extra" $1 && \
echo "Building main.bin in RELEASE mode." && \
odin build ../src/main.odin -file -out:main.bin -disable-assert -no-bounds-check -o:aggressive && \

cd ../ && \
"$ctime" -end snowball2_release.ctm %LastError% && \

echo "Done."
