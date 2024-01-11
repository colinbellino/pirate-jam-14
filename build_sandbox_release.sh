#!/bin/bash

ctime="./ctime/ctime.exe"
extra=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    extra="-extra-linker-flags:-F. -rpath @loader_path"
    ctime="./ctime/ctime"
fi

"$ctime" -begin sandbox_release.ctm

./build.exe && \

cd dist/ && \
echo "Building game0.dll in RELEASE mode." && \
odin build ../src/sandbox -out:game0.dll -build-mode:dll -no-bounds-check -o:aggressive -define:SOKOL_USE_GL=true "$extra" $1 && \
echo "Building main.exe in RELEASE mode." && \
odin build ../src/main.odin -file -out:main.exe -no-bounds-check -o:aggressive && \

cd ../ && \
"$ctime" -end sandbox_release.ctm %LastError% && \

echo "Done."
