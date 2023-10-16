rockspec_format = "3.0"
package = "lusc_luv"
version = "3.0.0-1"
source = {
   url = "git+https://github.com/svermeulen/lusc_luv.git",
   branch = "main"
}
description = {
   summary = "Structured Async/Concurrency for Lua using Luv",
   detailed = "Structured Async/Concurrency for Lua using Luv",
   homepage = "https://github.com/svermeulen/lusc_luv",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1",
   "luv",
}
build = {
   type = "builtin",
   modules = {
      lusc = "gen/lusc/init.lua",
      ["lusc.util"] = "gen/lusc/internal/util.lua"
      ["lusc.queue"] = "gen/lusc/internal/queue.lua"
   },
}
