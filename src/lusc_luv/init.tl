
local uv <const> = require("luv")
local lusc <const> = require("lusc")
local util <const> = require("lusc.util")

local record lusc_luv
end

function lusc_luv.get_time():number
   return uv.hrtime() / 1e9
end

function lusc_luv.sleep(seconds:number)
   uv.sleep(math.floor(seconds * 1000))
end

local function _get_opts(entry_point:function(lusc.Nursery), opts:lusc.Opts):lusc.Opts
   if opts == nil then
      opts = {}
   end

   util.assert(opts.time_provider == nil)

   opts = util.shallow_clone(opts)
   opts.entry_point = entry_point
   opts.time_provider = lusc_luv.get_time
   opts.sleep_handler = lusc_luv.sleep
   return opts
end

function lusc_luv.run(entry_point:function(lusc.Nursery), opts:lusc.Opts)
   lusc.run(_get_opts(entry_point, opts))
end

return lusc_luv
