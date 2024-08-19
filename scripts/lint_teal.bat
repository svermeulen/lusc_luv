@echo off
setlocal enabledelayedexpansion
call %~dp0setup_local_luarocks.bat
cd %~dp0\..
call luarocks\bin\tlcheck.bat src
echo Linting complete
endlocal

