local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local math = _tl_compat and _tl_compat.math or math
local uv = require("luv")
local lusc = require("lusc")
local util = require("lusc.util")

local lusc_luv = {}


function lusc_luv.get_time()
   return uv.hrtime() / 1e9
end

function lusc_luv.sleep(seconds)
   uv.sleep(math.floor(seconds * 1000))
end

local function _get_opts(entry_point, opts)
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

function lusc_luv.run(entry_point, opts)
   lusc.run(_get_opts(entry_point, opts))
end

return lusc_luv
