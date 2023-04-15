#!/bin/bash

./build_clean_up.sh

echo "Building tactics.bin in RELEASE mode."
./build_copy_libs_to_dist.sh
./build_copy_media_to_dist.sh
cd dist/ && odin build ../src/tactics.odin -file -out:tactics.bin -define=HOT_RELOAD_CODE=false -define=HOT_RELOAD_ASSETS=false -define:PROFILER=false -define:ASSETS_PATH="./" && cd ..
