rm -rf dist/ &&
./build_release.sh "-define:GAME_VOLUME_MAIN=0.0" && \
butler push ./dist/ colinbellino/the-legend-of-jan-itor:win
