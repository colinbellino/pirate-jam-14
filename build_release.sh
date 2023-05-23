#!/bin/bash

./build_clean_up.sh

echo "Building main.bin in RELEASE mode."
./build_copy_libs_to_dist.sh
./build_copy_media_to_dist.sh
cd dist/ && odin build ../src/main.odin -file -out:main.bin -define=HOT_RELOAD_CODE=false -define=HOT_RELOAD_ASSETS=false -define:TRACY_ENABLE=false -define:ASSETS_PATH="./" -extra-linker-flags:'-F. -rpath @loader_path' && cd ..
