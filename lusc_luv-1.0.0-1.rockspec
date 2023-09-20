rockspec_format = "3.0"
package = "lusc_luv"
version = "1.0.0-1"
source = {
   url = "git+https://github.com/svermeulen/lusc_luv.git",
   branch = "main"
}
description = {
   summary = "Structured Concurrency support for Lua",
   detailed = "Structured Concurrency support for Lua",
   homepage = "https://github.com/svermeulen/lusc_luv",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1",
   "lusc",
   "luv",
}
build = {
   type = "builtin",
   modules = {
      -- lusc = "gen/lusc/init.lua"
      -- ["lusc.util"] = "gen/lusc/util.lua"
   },
}
