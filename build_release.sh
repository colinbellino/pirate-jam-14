#!/bin/bash

./build_clean_up.sh

echo "Building tactics.bin in RELEASE mode."
./build_copy_files_to_dist.sh
cd dist/ && odin build ../src/tactics.odin -file -out:./tactics.bin -define=HOT_RELOAD=false -define:TRACY_ENABLE=false && cd ..
