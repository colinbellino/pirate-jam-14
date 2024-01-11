#!/bin/bash

extra=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    extra="-extra-linker-flags:-F. -rpath @loader_path"
fi

cd dist/
for i in {0..100}
do
    file="game$i.exe"
    if ! [[ -f "$file" ]]; then
        echo "Building $file."
        odin build ../src/stress -build-mode:dll -out:$file "$extra" --max-error-count=1 -disable-assert -no-bounds-check -o:speed -define:TRACY_ENABLE=true -define:PROFILER=true -define:GPU_PROFILER=false -define:LOG_ALLOC=false -define:IMGUI_ENABLE=true
        echo "  Done."
        exit 0
    fi
done
cd ..

>&2 echo "ERROR: hot-reload limit reached!"
exit 1
