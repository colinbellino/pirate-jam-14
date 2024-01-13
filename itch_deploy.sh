rm -rf dist/ &&
./build_release.sh "-define:GAME_VOLUME_MAIN=0.5" && \
butler push ./dist/ colinbellino/pirate-jam-14:win
