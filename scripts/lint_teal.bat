@echo off
setlocal enabledelayedexpansion
cd %~dp0\..
call luarocks\bin\tlcheck.bat src
echo Linting complete
endlocal

