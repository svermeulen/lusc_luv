@echo off
setlocal enabledelayedexpansion

cd %~dp0\..

set "REPO_ROOT=%~dp0..\"
set "LUAROCKS_TREE=!REPO_ROOT!luarocks"
set "LUA_PATH=!LUAROCKS_TREE!\share\lua\5.1\?.lua;!LUAROCKS_TREE!\share\lua\5.1\?\init.lua;;"
set "LUA_CPATH=!LUAROCKS_TREE!\lib\lua\5.1\?.dll;;"

if not exist "!LUAROCKS_TREE!\bin\busted.bat" (
    echo Local LuaRocks environment is not set up or busted is not installed.
    echo Please run scripts\setup_local_luarocks.bat first.
    endlocal
    exit /b 1
)

rem Navigate to the gen directory
cd gen

rem Run busted using the local luarocks installation
call !LUAROCKS_TREE!\bin\busted.bat . --config-file=..\busted_config.lua -v

endlocal
