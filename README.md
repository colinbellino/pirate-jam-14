# Pirate Jam 14

- Build in DEBUG mode and start RemedyBG (on Windows): `./run.sh`
- Build in RELEASE mode: `./build_release.sh`
- Build with vet options: `./build_vet.sh`
- Build game lib for hot reloading: `./build_hot.sh`
- Run tracy server: `TRACY_DPI_SCALE=1.0 ./src/odin-tracy/tracy/profiler/build/unix/Tracy-release`
- Print build stats: `./ctime/ctime -stats jam_debug.ctm` and `./ctime/ctime -stats jam_release.ctm`

Environment variables:
- `ODIN_ERROR_POS_STYLE="unix"`

Configs used by the game (-define:KEY=value):
- `ASSETS_PATH=""`
- `HOT_RELOAD_CODE=true`
- `HOT_RELOAD_ASSETS=true`
- `LOG_ALLOC=true`
- `IN_GAME_LOGGER=true`
- `IMGUI_ENABLE=true`
- `TRACY_ENABLE=true`
- `RENDER_ENABLE=true`
- `TITLE_STATS=true`
- `TITLE_SKIP=true`
