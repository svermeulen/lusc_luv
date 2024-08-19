@echo off
setlocal enabledelayedexpansion
cd %~dp0\..
rmdir /s /q gen
mkdir gen
mkdir gen\lusc
mkdir gen\lusc\internal
mkdir gen\lusc\tests
call luarocks\bin\tl.bat gen src\lusc\init.tl -o gen\lusc\init.lua
call luarocks\bin\tl.bat gen src\lusc\internal\util.tl -o gen\lusc\internal\util.lua
copy src\lusc\internal\queue.lua gen\lusc\internal\queue.lua
call luarocks\bin\tl.bat gen src\lusc\tests\async_helper.tl -o gen\lusc\tests\async_helper.lua
call luarocks\bin\tl.bat gen src\lusc\tests\lusc_spec.tl -o gen\lusc\tests\lusc_spec.lua
call luarocks\bin\tl.bat gen src\lusc\tests\setup.tl -o gen\lusc\tests\setup.lua
call luarocks\bin\tl.bat gen src\lusc\luv_async.tl -o gen\lusc\luv_async.lua
call luarocks\bin\tl.bat gen src\lusc\tests\luv_async_spec.tl -o gen\lusc\tests\luv_async_spec.lua
