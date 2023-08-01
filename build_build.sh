#!/bin/bash

odin build ./src/build.odin -file -out:build.exe -o=speed -extra-linker-flags:"-F src/sdl2"
