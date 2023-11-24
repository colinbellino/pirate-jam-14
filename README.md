# Snowball2

Build in DEBUG mode and start RemedyBG (on Windows): `./run.sh`
Build in RELEASE mode: `./build_release.sh`
Build with vet options: `./build_vet.sh`
Build game lib for hot reloading: `./build_hot.sh`
Run tracy server: `TRACY_DPI_SCALE=1.0 ./src/odin-tracy/tracy/profiler/build/unix/Tracy-release`
Print build stats: `./ctime/ctime -stats snowball2_debug.ctm` and `./ctime/ctime -stats snowball2_release.ctm`

Environment variables:
- `ODIN_ERROR_POS_STYLE="unix"`

Configs used by the game (-define:KEY=value):
- `ASSETS_PATH`
- `HOT_RELOAD_CODE`
- `HOT_RELOAD_ASSETS`
- `LOG_ALLOC`
- `IN_GAME_LOGGER`
- `GPU_PROFILER`
- `IMGUI_ENABLE`
- `IMGUI_GAME_VIEW`
- `TRACY_ENABLE`
- `RENDERER`
