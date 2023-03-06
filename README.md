# Project Tactics

Run (with hot-reload):
```shell
odin build ./src/game -build-mode:dll -out:game.bin ; odin run ./src/tactics.odin -file
```
Build (hot reload):
```shell
odin build ./src/game -build-mode:dll -out:game-hot0.bin
```

Build (debug):
```shell
odin build ./src/game -build-mode:dll -out:game.bin -debug ; odin run ./src/tactics.odin -file -debug
```

Placeholder assets:
- https://vryell.itch.io/tiny-village-pack
- https://vryell.itch.io/tiny-gui-pack
- RIPs from Secret of Mana, Alteration, JDG RPG3, Zelda
