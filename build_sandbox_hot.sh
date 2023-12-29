#!/bin/bash

extra=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    extra="-extra-linker-flags:-F. -rpath @loader_path"
fi

cd dist/
for i in {0..100}
do
    file="game$i.bin"
    if ! [[ -f "$file" ]]; then
        echo "Building $file."
        odin build ../src/sandbox -build-mode:dll -out:$file "$extra" --max-error-count=1 -debug -define:IMGUI_ENABLE=true -define:SOKOL_USE_GL=true
        echo "  Done."
        exit 0
    fi
done
cd ..

>&2 echo "ERROR: hot-reload limit reached!"
exit 1
