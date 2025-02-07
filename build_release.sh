#!/bin/bash

ctime="./ctime/ctime.exe"
extra=""
mode="-o:aggressive"
if [[ "$OSTYPE" == "darwin"* ]]; then
    extra="-extra-linker-flags:-F. -rpath @loader_path"
    mode="-o:speed"
    ctime="./ctime/ctime"
fi

"$ctime" -begin jam_release.ctm

./build.exe && \

cd dist/ && \
echo "Building game0.dll in RELEASE mode." && \
odin build ../src/game -out:game0.dll -build-mode:dll -disable-assert -no-bounds-check -define:SOKOL_USE_GL=true "$extra" $mode $1 && \
echo "Building main.exe in RELEASE mode." && \
odin build ../src/main.odin -file -out:main.exe -disable-assert -no-bounds-check "$extra" $mode $1 && \

cd ../ && \
"$ctime" -end jam_release.ctm %LastError% && \

echo "Done."
