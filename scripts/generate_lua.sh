#!/bin/bash
set -ex
cd `dirname $BASH_SOURCE`/..
rm -rf ./gen
mkdir ./gen
mkdir ./gen/lusc
mkdir ./gen/lusc/internal
mkdir ./gen/lusc/tests
luarocks_tree/bin/tl gen src/lusc/init.tl -o gen/lusc/init.lua
luarocks_tree/bin/tl gen src/lusc/internal/util.tl -o gen/lusc/internal/util.lua
cp src/lusc/internal/queue.lua gen/lusc/internal/queue.lua
luarocks_tree/bin/tl gen src/lusc/tests/async_helper.tl -o gen/lusc/tests/async_helper.lua
luarocks_tree/bin/tl gen src/lusc/tests/lusc_spec.tl -o gen/lusc/tests/lusc_spec.lua
luarocks_tree/bin/tl gen src/lusc/tests/setup.tl -o gen/lusc/tests/setup.lua
luarocks_tree/bin/tl gen src/lusc/luv_async.tl -o gen/lusc/luv_async.lua
luarocks_tree/bin/tl gen src/lusc/tests/luv_async_spec.tl -o gen/lusc/tests/luv_async_spec.lua
