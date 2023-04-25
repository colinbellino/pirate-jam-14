#!/bin/bash

echo "Copying libraries to dist/"

cp ./src/odin-tracy/tracy.dll dist/
cp ./src/odin-tracy/tracy.dylib dist/
cp ./src/odin-tracy/tracy.lib dist/

cp ./src/sdl2/SDL2.lib dist/
cp ./src/sdl2/SDL2.dll dist/
cp -rf ./src/sdl2/SDL2.framework dist/

# cp ./src/sdl2/SDL2_image.dll dist/
# cp ./src/sdl2/SDL2_image.lib dist/
# cp -rf ./src/sdl2/SDL2_image.framework dist/
