#!/bin/bash

./build_clean_up.sh
./build_copy_files_to_dist.sh

echo "Building asset_builder.bin."
cd dist/ && odin run ../src/asset_builder -out:./asset_builder.bin && cd ..
