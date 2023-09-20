local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local coroutine = _tl_compat and _tl_compat.coroutine or coroutine; local math = _tl_compat and _tl_compat.math or math
local uv = require("luv")
local lusc = require("lusc")
local util = require("lusc.util")
local LuscBackgroundRunner = require("lusc_luv.background_runner")

local lusc_luv = {}


function lusc_luv.get_time()
   return uv.hrtime() / 1e9
end

local function _get_opts(opts)
   if opts == nil then
      opts = {}
   end

   util.assert(opts.time_provider == nil)

   opts = util.shallow_clone(opts)
   opts.time_provider = lusc_luv.get_time
   return opts
end

function lusc_luv.run_in_background(opts)
   local runner = LuscBackgroundRunner.new()
   runner:_initialize(_get_opts(opts))
   return runner
end

function lusc_luv.run(entry_point, opts)
   local pending_jobs = { entry_point }
   local coro = lusc.run(_get_opts(opts))

   while true do
      local ok, result = coroutine.resume(coro, pending_jobs)
      pending_jobs = {}

      if not ok then
         error(result)
      end

      if result == lusc.NO_MORE_TASKS_SIGNAL then
         break
      end

      util.assert(type(result) == "number")
      local seconds = result
      uv.sleep(math.floor(seconds * 1000))
   end
end

return lusc_luv
