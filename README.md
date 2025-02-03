# Pirate Jam 14

Adventurers are spreading a lot of slime and other mess in the dungeon and you are the one tasked to clean it up before it becomes out of hand.

![image](https://github.com/user-attachments/assets/fbdbb787-e30e-482d-82f5-b10612e86351)

Note: this game was made in 10 days by a team of 3 people for the Pirate Software game jam. This game was developed as an experiment and way of dog-fooding a custom, handmade game engine i am working on (written in the Odin language).

# Dev notes
(never took the time to clean those up since i didn't plan on the source code going public, sorry)

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
