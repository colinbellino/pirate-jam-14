#!/bin/bash

./ctime/ctime -begin snowball2_release.ctm

extra=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    extra="-extra-linker-flags:-F. -rpath @loader_path"
fi

./build.exe --CLEAN_UP_CODE && \

cd dist/ && \
echo "Building game0.bin in RELEASE mode." && \
odin build ../src/game -out:game0.bin -build-mode:dll -disable-assert -no-bounds-check "$extra" $1 && \
echo "Building main.bin in RELEASE mode." && \
odin build ../src/main.odin -file -out:main.bin -disable-assert -no-bounds-check && \
# FIXME: Use -o:aggressive again once is fixed: https://github.com/odin-lang/Odin/issues/2881
#        After reading more about it, this might not be related to this at all and could simply be me doing something really dumb. I need to investigate how to debug the compiler...

cd ../ && \
./ctime/ctime -end snowball2_release.ctm %LastError% && \

echo "Done."
