#!/bin/bash
set -e

./setup_local_luarocks.sh
./generate_lua.sh

# Navigate to the root of the repo
cd "$(dirname "$0")/.."

# Set the local LuaRocks tree paths
REPO_ROOT="$(pwd)"
LUAROCKS_TREE="$REPO_ROOT/luarocks_tree"
export LUA_PATH="$LUAROCKS_TREE/share/lua/5.1/?.lua;$LUAROCKS_TREE/share/lua/5.1/?/init.lua;;"
export LUA_CPATH="$LUAROCKS_TREE/lib/lua/5.1/?.so;;"

# Check if local LuaRocks tree and busted are set up
if [ ! -f "$LUAROCKS_TREE/bin/busted" ]; then
    echo "Local LuaRocks environment is not set up or busted is not installed."
    echo "Please run scripts/setup_local_luarocks.sh first."
    exit 1
fi

# Navigate to the gen directory
cd gen

# Run busted using the local LuaRocks installation
"$LUAROCKS_TREE/bin/busted" . --config-file=../busted_config.lua -v
